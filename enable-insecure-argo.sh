#!/usr/bin/env bash
# Coloca o argocd-server em modo insecure (HTTP puro, sem redirect pra HTTPS),
# para que a porta 80 funcione no navegador. Rode uma vez.
set -euo pipefail

echo "==> Aplicando argocd-cmd-params-cm (server.insecure=true)..."
kubectl apply -f "$(dirname "$0")/argocd/argocd-cmd-params-cm.yaml"

echo "==> Reiniciando o argocd-server..."
kubectl -n argocd rollout restart deploy/argocd-server
kubectl -n argocd rollout status deploy/argocd-server --timeout=120s

echo "==> Pronto. Agora use ./access-argo.sh para abrir em http://localhost:8081"
