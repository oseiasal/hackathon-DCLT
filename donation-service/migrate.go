package main

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"io/fs"
	"log/slog"
	"sort"
	"strings"
)

//go:embed db/migrations/*.sql
var migrationsFS embed.FS

func ensureMigrationsTable(ctx context.Context, db *sql.DB) error {
	_, err := db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version VARCHAR(255) PRIMARY KEY,
			applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		);
	`)
	return err
}

func getAppliedMigrations(ctx context.Context, db *sql.DB) (map[string]bool, error) {
	rows, err := db.QueryContext(ctx, "SELECT version FROM schema_migrations ORDER BY version")
	if err != nil {
		return nil, err
	}
	defer func() { _ = rows.Close() }()

	applied := make(map[string]bool)
	for rows.Next() {
		var version string
		if err := rows.Scan(&version); err != nil {
			return nil, err
		}
		applied[version] = true
	}
	return applied, rows.Err()
}

func listEmbeddedMigrations() ([]string, error) {
	entries, err := fs.ReadDir(migrationsFS, "db/migrations")
	if err != nil {
		return nil, err
	}

	var files []string
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".sql") {
			files = append(files, entry.Name())
		}
	}
	sort.Strings(files)
	return files, nil
}

func runMigrations(ctx context.Context, db *sql.DB, logger *slog.Logger) error {
	if err := ensureMigrationsTable(ctx, db); err != nil {
		return fmt.Errorf("erro ao criar tabela schema_migrations: %w", err)
	}

	applied, err := getAppliedMigrations(ctx, db)
	if err != nil {
		return fmt.Errorf("erro ao consultar migrations aplicadas: %w", err)
	}

	files, err := listEmbeddedMigrations()
	if err != nil {
		return fmt.Errorf("erro ao listar migrations embutidas: %w", err)
	}

	executed := 0
	for _, version := range files {
		if applied[version] {
			logger.Info("Migration já aplicada; ignorando", "migration", version)
			continue
		}

		content, err := fs.ReadFile(migrationsFS, "db/migrations/"+version)
		if err != nil {
			return fmt.Errorf("erro ao ler migration %s: %w", version, err)
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			return fmt.Errorf("erro ao iniciar transação para %s: %w", version, err)
		}

		if _, err := tx.ExecContext(ctx, string(content)); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("erro ao executar migration %s: %w", version, err)
		}

		if _, err := tx.ExecContext(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", version); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("erro ao registrar migration %s: %w", version, err)
		}

		if err := tx.Commit(); err != nil {
			return fmt.Errorf("erro ao confirmar migration %s: %w", version, err)
		}

		executed++
		logger.Info("Migration aplicada com sucesso", "migration", version)
	}

	logger.Info("Processo de migrations concluído", "applied", executed)
	return nil
}

func printMigrationStatus(ctx context.Context, db *sql.DB, logger *slog.Logger) error {
	if err := ensureMigrationsTable(ctx, db); err != nil {
		return fmt.Errorf("erro ao verificar tabela schema_migrations: %w", err)
	}

	appliedMap, err := getAppliedMigrations(ctx, db)
	if err != nil {
		return fmt.Errorf("erro ao consultar migrations aplicadas: %w", err)
	}

	files, err := listEmbeddedMigrations()
	if err != nil {
		return fmt.Errorf("erro ao listar migrations embutidas: %w", err)
	}

	var applied, pending []string
	for _, version := range files {
		if appliedMap[version] {
			applied = append(applied, version)
		} else {
			pending = append(pending, version)
		}
	}

	logger.Info("Status das migrations", "applied", applied, "pending", pending)
	return nil
}
