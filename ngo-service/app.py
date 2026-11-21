import atexit
from datetime import datetime, timezone
import json
import logging
import os
import sys
import time
import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2.pool import SimpleConnectionPool
from flask import Flask, g, request, jsonify
from dotenv import load_dotenv

SERVICE_NAME = "ngo-service"


class JsonFormatter(logging.Formatter):
    def format(self, record):
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "service": SERVICE_NAME,
            "message": record.getMessage(),
        }
        for key in ("method", "path", "status", "duration_ms", "dependency", "error"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def setup_logger():
    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(level)

    logging.getLogger("werkzeug").setLevel(logging.WARNING)
    return logging.getLogger(SERVICE_NAME)


load_dotenv()
log = setup_logger()

app = Flask(__name__)

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    log.critical("DATABASE_URL não definida.")
    sys.exit(1)

try:
    pool = SimpleConnectionPool(1, 10, dsn=DATABASE_URL, connect_timeout=5)
    log.info("Pool de conexões com o PostgreSQL inicializado.")
except Exception as e:
    log.critical("Erro ao conectar ao PostgreSQL.", extra={"error": str(e)})
    sys.exit(1)


def close_pool():
    try:
        pool.closeall()
        log.info("Pool de conexões PostgreSQL encerrado com segurança.")
    except Exception as e:
        log.error("Erro ao fechar pool PostgreSQL.", extra={"error": str(e)})


atexit.register(close_pool)


@app.before_request
def start_timer():
    g.start_time = time.perf_counter()


@app.after_request
def log_request(response):
    duration_ms = round((time.perf_counter() - getattr(g, "start_time", time.perf_counter())) * 1000, 2)
    log.info(
        "http_request",
        extra={
            "method": request.method,
            "path": request.path,
            "status": response.status_code,
            "duration_ms": duration_ms,
        },
    )
    return response


@app.route('/health')
@app.route('/health/live')
def health():
    return jsonify({"status": "ok", "service": SERVICE_NAME}), 200


@app.route('/health/ready')
def ready():
    conn = None
    broken = False
    try:
        conn = pool.getconn()
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
        return jsonify({"status": "ready", "service": SERVICE_NAME, "checks": {"postgres": "ok"}}), 200
    except Exception as e:
        broken = True
        log.warning("Readiness check falhou.", extra={"dependency": "postgres", "error": str(e)})
        return jsonify({"status": "not_ready", "service": SERVICE_NAME, "checks": {"postgres": "error"}}), 503
    finally:
        if conn is not None:
            pool.putconn(conn, close=broken)


@app.route('/ngos', methods=['POST'])
def create_ngo():
    data = request.get_json()
    if not data or not all(k in data for k in ('name', 'email', 'cause', 'city')):
        return jsonify({"error": "Campos obrigatórios ausentes"}), 400

    conn = pool.getconn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "INSERT INTO ngos (name, email, cause, city) VALUES (%s, %s, %s, %s) RETURNING *",
                (data['name'], data['email'], data['cause'], data['city'])
            )
            new_ngo = cur.fetchone()
            conn.commit()
            return jsonify(new_ngo), 201
    except psycopg2.IntegrityError:
        conn.rollback()
        return jsonify({"error": "E-mail já cadastrado"}), 409
    except Exception as e:
        conn.rollback()
        log.error("Erro ao criar ONG.", extra={"error": str(e)})
        return jsonify({"error": "Erro interno"}), 500
    finally:
        pool.putconn(conn)


@app.route('/ngos', methods=['GET'])
def get_ngos():
    conn = pool.getconn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM ngos ORDER BY id DESC")
            return jsonify(cur.fetchall()), 200
    except Exception as e:
        log.error("Erro ao buscar ONGs.", extra={"error": str(e)})
        return jsonify({"error": "Erro interno"}), 500
    finally:
        pool.putconn(conn)


if __name__ == '__main__':
    port = int(os.getenv("PORT", 8081))
    app.run(host='0.0.0.0', port=port)
