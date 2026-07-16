#!/usr/bin/env bash
# Deploy da API NestJS no minikube.
# Uso: ./deploy.sh [main|dev|all]
set -euo pipefail

TARGET="${1:-all}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ">> Habilitando metrics-server (necessário para o HPA)..."
minikube addons enable metrics-server

echo ">> Apontando o docker local para o daemon do minikube..."
eval "$(minikube docker-env)"

deploy_env() {
  local env="$1"
  echo ">> Buildando imagem nest-api:${env}..."
  docker build -t "nest-api:${env}" "${REPO_DIR}/app"

  echo ">> Criando namespace nest-api-${env} (se não existir)..."
  kubectl create namespace "nest-api-${env}" --dry-run=client -o yaml | kubectl apply -f -

  echo ">> Aplicando manifests do overlay ${env}..."
  kubectl apply -k "${REPO_DIR}/manifests/overlays/${env}"

  echo ">> Aguardando rollout..."
  kubectl rollout status "deployment/nest-api" -n "nest-api-${env}" --timeout=180s
}

case "$TARGET" in
  main|dev) deploy_env "$TARGET" ;;
  all)
    deploy_env dev
    deploy_env main
    ;;
  *)
    echo "Uso: $0 [main|dev|all]" >&2
    exit 1
    ;;
esac

echo ""
echo ">> Pronto! Para acessar a API:"
echo "   kubectl port-forward svc/nest-api 8080:80 -n nest-api-main"
echo "   curl http://localhost:8080/"
echo ""
echo ">> Para observar com o k9s: k9s -n nest-api-main"
