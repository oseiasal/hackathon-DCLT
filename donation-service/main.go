package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
	_ "github.com/jackc/pgx/v4/stdlib"
	"github.com/joho/godotenv"
)

const serviceName = "donation-service"

type Donation struct {
	ID        int       `json:"id"`
	NgoID     int       `json:"ngo_id"`
	Amount    float64   `json:"amount"`
	DonorName string    `json:"donor_name"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

type App struct {
	DB          *sql.DB
	SqsSvc      *sqs.SQS
	SqsQueueURL string
	Logger      *slog.Logger
	wg          sync.WaitGroup
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (sr *statusRecorder) WriteHeader(code int) {
	sr.statusCode = code
	sr.ResponseWriter.WriteHeader(code)
}

func setupLogger() *slog.Logger {
	var level slog.Level
	switch strings.ToUpper(os.Getenv("LOG_LEVEL")) {
	case "DEBUG":
		level = slog.LevelDebug
	case "WARN", "WARNING":
		level = slog.LevelWarn
	case "ERROR":
		level = slog.LevelError
	default:
		level = slog.LevelInfo
	}

	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: level})
	return slog.New(handler).With("service", serviceName)
}

func getEnvInt(key string, defaultVal int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return defaultVal
	}
	v, err := strconv.Atoi(raw)
	if err != nil || v <= 0 {
		return defaultVal
	}
	return v
}

func main() {
	_ = godotenv.Load()

	logger := setupLogger()
	slog.SetDefault(logger)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8082"
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		logger.Error("DATABASE_URL é obrigatória")
		os.Exit(1)
	}

	db, err := sql.Open("pgx", dbURL)
	if err != nil {
		logger.Error("Erro ao abrir conexão com o banco de dados", "error", err)
		os.Exit(1)
	}

	maxOpenConns := getEnvInt("DB_MAX_OPEN_CONNS", 25)
	maxIdleConns := getEnvInt("DB_MAX_IDLE_CONNS", 5)
	connMaxLifetimeSec := getEnvInt("DB_CONN_MAX_LIFETIME_SEC", 300)
	connMaxIdleTimeSec := getEnvInt("DB_CONN_MAX_IDLE_TIME_SEC", 60)

	db.SetMaxOpenConns(maxOpenConns)
	db.SetMaxIdleConns(maxIdleConns)
	db.SetConnMaxLifetime(time.Duration(connMaxLifetimeSec) * time.Second)
	db.SetConnMaxIdleTime(time.Duration(connMaxIdleTimeSec) * time.Second)

	pingCtx, pingCancel := context.WithTimeout(context.Background(), 5*time.Second)
	err = db.PingContext(pingCtx)
	pingCancel()
	if err != nil {
		logger.Error("Erro ao conectar ao banco de dados", "error", err)
		_ = db.Close()
		os.Exit(1)
	}
	logger.Info("Conectado ao PostgreSQL",
		"max_open_conns", maxOpenConns,
		"max_idle_conns", maxIdleConns,
		"conn_max_lifetime_sec", connMaxLifetimeSec,
		"conn_max_idle_time_sec", connMaxIdleTimeSec,
	)

	if len(os.Args) > 1 {
		cmdCtx, cmdCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cmdCancel()
		defer db.Close()

		switch os.Args[1] {
		case "migrate":
			if err := runMigrations(cmdCtx, db, logger); err != nil {
				logger.Error("Falha ao executar migrations", "error", err)
				os.Exit(1)
			}
			return
		case "migrate-status":
			if err := printMigrationStatus(cmdCtx, db, logger); err != nil {
				logger.Error("Falha ao consultar status das migrations", "error", err)
				os.Exit(1)
			}
			return
		default:
			logger.Error("Subcomando inválido; use: migrate | migrate-status", "arg", os.Args[1])
			os.Exit(2)
		}
	}

	var sqsSvc *sqs.SQS
	queueURL := os.Getenv("AWS_SQS_URL")
	region := os.Getenv("AWS_REGION")
	if queueURL != "" && region != "" {
		awsCfg := aws.Config{Region: aws.String(region)}
		if endpoint := os.Getenv("AWS_ENDPOINT_URL"); endpoint != "" {
			awsCfg.Endpoint = aws.String(endpoint)
		}
		sess, err := session.NewSessionWithOptions(session.Options{
			Config:            awsCfg,
			SharedConfigState: session.SharedConfigEnable,
		})
		if err != nil {
			logger.Error("Erro ao inicializar sessão AWS", "error", err)
			_ = db.Close()
			os.Exit(1)
		}
		sqsSvc = sqs.New(sess)
		logger.Info("Integração com AWS SQS ativada", "region", region)
	}

	app := &App{
		DB:          db,
		SqsSvc:      sqsSvc,
		SqsQueueURL: queueURL,
		Logger:      logger,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.HealthHandler)
	mux.HandleFunc("/health/live", app.HealthHandler)
	mux.HandleFunc("/health/ready", app.ReadyHandler)
	mux.HandleFunc("/donations", app.DonationHandler)

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           app.loggingMiddleware(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("Servidor HTTP iniciado", "port", port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("Erro fatal no servidor HTTP", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	logger.Info("Sinal de encerramento recebido; iniciando graceful shutdown")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("Erro durante shutdown do servidor HTTP", "error", err)
	}

	logger.Info("Aguardando eventos assíncronos em voo")
	app.wg.Wait()

	if err := db.Close(); err != nil {
		logger.Error("Erro ao fechar conexão com PostgreSQL", "error", err)
	}

	logger.Info("Encerramento concluído com segurança")
}

func (a *App) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(rec, r)

		a.Logger.Info("http_request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.statusCode,
			"duration_ms", float64(time.Since(start).Microseconds())/1000.0,
		)
	})
}

func (a *App) HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok","service":"donation-service"}`))
}

func (a *App) ReadyHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	if err := a.DB.PingContext(ctx); err != nil {
		a.Logger.Warn("Readiness check falhou", "dependency", "postgres", "error", err)
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"status":"not_ready","service":"donation-service","checks":{"postgres":"error"}}`))
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ready","service":"donation-service","checks":{"postgres":"ok"}}`))
}

func (a *App) DonationHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method == http.MethodPost {
		var d Donation
		if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
			http.Error(w, `{"error":"Payload inválido"}`, http.StatusBadRequest)
			return
		}

		d.Status = "APPROVED" // Simulação de gateway de pagamento
		err := a.DB.QueryRowContext(
			r.Context(),
			"INSERT INTO donations (ngo_id, amount, donor_name, status) VALUES ($1, $2, $3, $4) RETURNING id, created_at",
			d.NgoID, d.Amount, d.DonorName, d.Status,
		).Scan(&d.ID, &d.CreatedAt)

		if err != nil {
			a.Logger.Error("Erro ao salvar doação", "error", err)
			http.Error(w, `{"error":"Erro interno"}`, http.StatusInternalServerError)
			return
		}

		if a.SqsSvc != nil {
			a.wg.Add(1)
			go a.sendNotificationEvent(d)
		}

		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(d)
		return
	}

	if r.Method == http.MethodGet {
		rows, err := a.DB.QueryContext(r.Context(), "SELECT id, ngo_id, amount, donor_name, status, created_at FROM donations ORDER BY id DESC")
		if err != nil {
			a.Logger.Error("Erro ao listar doações", "error", err)
			http.Error(w, `{"error":"Erro interno"}`, http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		donations := []Donation{}
		for rows.Next() {
			var d Donation
			rows.Scan(&d.ID, &d.NgoID, &d.Amount, &d.DonorName, &d.Status, &d.CreatedAt)
			donations = append(donations, d)
		}

		json.NewEncoder(w).Encode(donations)
		return
	}

	http.Error(w, `{"error":"Método não permitido"}`, http.StatusMethodNotAllowed)
}

func (a *App) sendNotificationEvent(d Donation) {
	defer a.wg.Done()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	body, _ := json.Marshal(d)
	_, err := a.SqsSvc.SendMessageWithContext(ctx, &sqs.SendMessageInput{
		MessageBody: aws.String(string(body)),
		QueueUrl:    aws.String(a.SqsQueueURL),
	})
	if err != nil {
		a.Logger.Error("Falha ao despachar evento SQS", "donation_id", d.ID, "error", err)
		return
	}

	a.Logger.Info("Evento SQS despachado", "donation_id", d.ID)
}
