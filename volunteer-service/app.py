from datetime import datetime, timezone
import json
import logging
import os
import sys
import time
import uuid
import boto3
from boto3.dynamodb.conditions import Key
from botocore.config import Config
from flask import Flask, g, request, jsonify
from dotenv import load_dotenv

SERVICE_NAME = "volunteer-service"


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

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
DYNAMODB_TABLE = os.getenv("AWS_DYNAMODB_TABLE")
DYNAMODB_NGO_INDEX = os.getenv("AWS_DYNAMODB_NGO_INDEX", "ngo_id-index")

if not DYNAMODB_TABLE:
    log.critical("AWS_DYNAMODB_TABLE não definida.")
    sys.exit(1)

try:
    boto_config = Config(connect_timeout=5, read_timeout=10, retries={"max_attempts": 3})
    dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION, config=boto_config)
    table = dynamodb.Table(DYNAMODB_TABLE)
    log.info(f"Cliente DynamoDB inicializado para a tabela: {DYNAMODB_TABLE}")
except Exception as e:
    log.critical("Falha ao inicializar cliente DynamoDB.", extra={"error": str(e)})
    sys.exit(1)


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
    try:
        dynamodb.meta.client.describe_table(TableName=DYNAMODB_TABLE)
        return jsonify({"status": "ready", "service": SERVICE_NAME, "checks": {"dynamodb": "ok"}}), 200
    except Exception as e:
        log.warning("Readiness check falhou.", extra={"dependency": "dynamodb", "error": str(e)})
        return jsonify({"status": "not_ready", "service": SERVICE_NAME, "checks": {"dynamodb": "error"}}), 503


@app.route('/volunteers', methods=['POST'])
def register_volunteer():
    data = request.get_json()
    if not data or not all(k in data for k in ('name', 'email', 'ngo_id')):
        return jsonify({"error": "Campos obrigatórios ausentes"}), 400

    volunteer_id = str(uuid.uuid4())
    item = {
        'volunteer_id': volunteer_id,
        'name': data['name'],
        'email': data['email'],
        'ngo_id': int(data['ngo_id']),
        'registered_at': str(int(time.time()))
    }

    try:
        table.put_item(Item=item)
        return jsonify(item), 201
    except Exception as e:
        log.error("Erro ao salvar voluntário no DynamoDB.", extra={"error": str(e)})
        return jsonify({"error": "Erro interno ao processar dados"}), 500


@app.route('/volunteers/<int:ngo_id>', methods=['GET'])
def get_volunteers_by_ngo(ngo_id):
    try:
        response = table.query(
            IndexName=DYNAMODB_NGO_INDEX,
            KeyConditionExpression=Key('ngo_id').eq(ngo_id),
        )
        items = response.get('Items', [])
        while 'LastEvaluatedKey' in response:
            response = table.query(
                IndexName=DYNAMODB_NGO_INDEX,
                KeyConditionExpression=Key('ngo_id').eq(ngo_id),
                ExclusiveStartKey=response['LastEvaluatedKey'],
            )
            items.extend(response.get('Items', []))
        return jsonify(items), 200
    except Exception as e:
        log.error("Erro ao buscar dados no DynamoDB.", extra={"error": str(e)})
        return jsonify({"error": "Erro interno"}), 500


if __name__ == '__main__':
    port = int(os.getenv("PORT", 8083))
    app.run(host='0.0.0.0', port=port)
