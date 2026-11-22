#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SolidaryTech — Teardown Kubernetes (Amazon EKS)
# Remove aplicações, Ingress NGINX (e seu Load Balancer AWS) e External Secrets
# Operator na ordem inversa segura antes de rodar `terragrunt destroy`.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-solidarytech-dev-eks}"
K8S_OVERLAY="${K8S_OVERLAY:-${REPO_ROOT}/infra/k8s/overlays/dev}"
APP_NAMESPACE="${APP_NAMESPACE:-solidarytech}"

echo "==> [1/5] Validando ferramentas e conectando ao cluster '${EKS_CLUSTER_NAME}'..."
for cmd in aws kubectl helm; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERRO: comando '${cmd}' não encontrado no PATH." >&2
    exit 1
  fi
done
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${EKS_CLUSTER_NAME}"

echo "==> [2/5] Removendo manifestos da aplicação (${K8S_OVERLAY})..."
kubectl delete -k "${K8S_OVERLAY}" --ignore-not-found=true --wait=true || true

echo "==> [3/5] Removendo Ingress NGINX (liberando Load Balancer / ENIs na AWS)..."
if helm status ingress-nginx -n ingress-nginx >/dev/null 2>&1; then
  helm uninstall ingress-nginx -n ingress-nginx --wait --timeout 5m
fi
kubectl delete namespace ingress-nginx --ignore-not-found=true --wait=true --timeout=180s

echo "==> [4/5] Removendo External Secrets Operator..."
if helm status external-secrets -n external-secrets >/dev/null 2>&1; then
  helm uninstall external-secrets -n external-secrets --wait --timeout 5m
fi
kubectl delete namespace external-secrets --ignore-not-found=true --wait=true --timeout=180s

echo "==> [5/5] Garantindo remoção do namespace '${APP_NAMESPACE}'..."
kubectl delete namespace "${APP_NAMESPACE}" --ignore-not-found=true --wait=true --timeout=180s

echo ""
echo "Teardown Kubernetes concluído com sucesso! Cluster limpo para 'terragrunt destroy'."
