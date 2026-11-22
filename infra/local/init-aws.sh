#!/bin/sh
set -e

PORT="${AWS_EMULATOR_PORT:-9297}"
REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${AWS_DYNAMODB_TABLE:-SolidaryTechVolunteers}"
NGO_INDEX_NAME="${AWS_DYNAMODB_NGO_INDEX:-ngo_id-index}"
QUEUE_NAME="${AWS_SQS_QUEUE_NAME:-solidary-donations}"

export AWS_ENDPOINT_URL="https://127.0.0.1:${PORT}"
export AWS_CA_BUNDLE="/aws-emulator/${PORT}/ca.pem"
export AWS_SHARED_CREDENTIALS_FILE="/aws-emulator/${PORT}/emulator_credentials"
export AWS_CONFIG_FILE="/aws-emulator/${PORT}/config"
export AWS_DEFAULT_REGION="${REGION}"
export AWS_PAGER=""

echo "Aguardando AWS Emulator ficar pronto em ${AWS_ENDPOINT_URL}..."
for i in $(seq 1 30); do
  if [ -f "${AWS_CA_BUNDLE}" ] && [ -f "${AWS_SHARED_CREDENTIALS_FILE}" ]; then
    if aws sqs list-queues >/dev/null 2>&1; then
      break
    fi
  fi
  sleep 1
done

echo "Criando fila SQS: ${QUEUE_NAME}..."
QUEUE_URL=$(aws sqs create-queue \
  --queue-name "${QUEUE_NAME}" \
  --region "${REGION}" \
  --query 'QueueUrl' \
  --output text)
echo "Fila SQS pronta: ${QUEUE_URL}"

echo "Criando tabela DynamoDB: ${TABLE_NAME}..."
if aws dynamodb describe-table --table-name "${TABLE_NAME}" --region "${REGION}" >/dev/null 2>&1; then
  echo "Tabela DynamoDB ${TABLE_NAME} já existe."
else
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions \
      AttributeName=volunteer_id,AttributeType=S \
      AttributeName=ngo_id,AttributeType=N \
    --key-schema AttributeName=volunteer_id,KeyType=HASH \
    --global-secondary-indexes "[{\"IndexName\":\"${NGO_INDEX_NAME}\",\"KeySchema\":[{\"AttributeName\":\"ngo_id\",\"KeyType\":\"HASH\"}],\"Projection\":{\"ProjectionType\":\"ALL\"}}]" \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" >/dev/null
  echo "Tabela DynamoDB ${TABLE_NAME} criada com sucesso (com GSI ${NGO_INDEX_NAME})."
fi

echo "Provisionamento local no AWS Emulator concluído."
