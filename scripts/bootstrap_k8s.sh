#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SolidaryTech — Bootstrap Kubernetes (Amazon EKS)
# Configura kubeconfig, instala Ingress NGINX + External Secrets Operator (Helm)
# e aplica os manifestos Kustomize (overlay dev por padrão).
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-solidarytech-dev-eks}"
K8S_OVERLAY="${K8S_OVERLAY:-${REPO_ROOT}/infra/k8s/overlays/dev}"
APP_NAMESPACE="${APP_NAMESPACE:-solidarytech}"

echo "==> [1/6] Validando pré-requisitos (aws, kubectl, helm)..."
for cmd in aws kubectl helm; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERRO: comando '${cmd}' não encontrado no PATH." >&2
    exit 1
  fi
done

echo "==> [2/6] Configurando kubeconfig para o cluster EKS '${EKS_CLUSTER_NAME}' (${AWS_REGION})..."
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${EKS_CLUSTER_NAME}"
kubectl get nodes

echo "==> [3/6] Instalando/atualizando Ingress NGINX via Helm..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
helm repo update >/dev/null

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --wait \
  --timeout 5m

echo "==> [4/6] Instalando/atualizando External Secrets Operator via Helm..."
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --wait \
  --timeout 5m

echo "==> [5/6] Aplicando manifestos Kustomize (${K8S_OVERLAY})..."
kubectl apply -k "${K8S_OVERLAY}"

echo "==> [6/6] Aguardando sincronização dos ExternalSecrets e rollout dos Deployments..."
kubectl wait --for=condition=Ready externalsecret/solidarytech-db-credentials -n "${APP_NAMESPACE}" --timeout=120s || true
kubectl wait --for=condition=Ready externalsecret/solidarytech-runtime-config -n "${APP_NAMESPACE}" --timeout=120s || true

for deploy in ngo-service donation-service volunteer-service; do
  kubectl rollout status "deployment/${deploy}" -n "${APP_NAMESPACE}" --timeout=180s
done

echo ""
echo "=== Status dos recursos em '${APP_NAMESPACE}' ==="
kubectl get secretstore,externalsecret,jobs,pods,svc,hpa,ingress -n "${APP_NAMESPACE}"

LB_HOST="$(kubectl get ingress solidarytech-ingress -n "${APP_NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
if [[ -n "${LB_HOST}" ]]; then
  echo ""
  echo "=== Endpoints públicos disponíveis ==="
  echo "  NGOs:        http://${LB_HOST}/ngos"
  echo "  Donations:   http://${LB_HOST}/donations"
  echo "  Volunteers:  http://${LB_HOST}/volunteers/1"
else
  echo ""
  echo "AVISO: O Load Balancer ainda está sendo provisionado pela AWS."
  echo "Acompanhe com: kubectl get ingress solidarytech-ingress -n ${APP_NAMESPACE} -w"
fi
