from datetime import datetime, timezone
import json
import logging
import os
from pathlib import Path
import sys
import psycopg2
from dotenv import load_dotenv

SERVICE_NAME = "ngo-service-admin"
MIGRATIONS_DIR = Path(__file__).resolve().parent / "db" / "migrations"


class JsonFormatter(logging.Formatter):
    def format(self, record):
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "service": SERVICE_NAME,
            "message": record.getMessage(),
        }
        for key in ("migration", "applied", "pending", "error"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        return json.dumps(payload, ensure_ascii=False)


def setup_logger():
    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    logger = logging.getLogger(SERVICE_NAME)
    logger.handlers.clear()
    logger.addHandler(handler)
    logger.setLevel(level)
    logger.propagate = False
    return logger


def ensure_migrations_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
            """
        )
    conn.commit()


def get_applied_versions(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT version FROM schema_migrations ORDER BY version")
        return {row[0] for row in cur.fetchall()}


def list_migration_files():
    if not MIGRATIONS_DIR.exists():
        return []
    return sorted(MIGRATIONS_DIR.glob("*.sql"))


def run_migrate(conn, log):
    ensure_migrations_table(conn)
    applied = get_applied_versions(conn)
    files = list_migration_files()
    executed = 0

    for migration_file in files:
        version = migration_file.name
        if version in applied:
            log.info("Migration já aplicada; ignorando.", extra={"migration": version})
            continue

        sql = migration_file.read_text(encoding="utf-8")
        try:
            with conn.cursor() as cur:
                cur.execute(sql)
                cur.execute(
                    "INSERT INTO schema_migrations (version) VALUES (%s)",
                    (version,),
                )
            conn.commit()
            executed += 1
            log.info("Migration aplicada com sucesso.", extra={"migration": version})
        except Exception as e:
            conn.rollback()
            log.error("Falha ao aplicar migration.", extra={"migration": version, "error": str(e)})
            raise

    log.info("Processo de migrations concluído.", extra={"applied": executed})


def run_status(conn, log):
    ensure_migrations_table(conn)
    applied = get_applied_versions(conn)
    files = [f.name for f in list_migration_files()]
    pending = [f for f in files if f not in applied]
    log.info(
        "Status das migrations.",
        extra={"applied": sorted(applied), "pending": pending},
    )


def main():
    load_dotenv()
    log = setup_logger()

    if len(sys.argv) < 2 or sys.argv[1] not in ("migrate", "status"):
        log.error("Uso: python manage.py [migrate|status]")
        sys.exit(2)

    command = sys.argv[1]
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        log.critical("DATABASE_URL não definida.")
        sys.exit(1)

    conn = None
    try:
        conn = psycopg2.connect(dsn=database_url, connect_timeout=5)
        if command == "migrate":
            run_migrate(conn, log)
        elif command == "status":
            run_status(conn, log)
    except Exception as e:
        log.critical("Erro no processo administrativo.", extra={"error": str(e)})
        sys.exit(1)
    finally:
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    main()
