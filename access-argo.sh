#!/usr/bin/env bash
# Expõe o ArgoCD em https://localhost:8081 (port-forward do argocd-server).
# Rode depois do `minikube start`. Mantenha o terminal aberto enquanto usa.
set -euo pipefail

PORT="${1:-8081}"

echo "==> Aguardando o argocd-server ficar pronto..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=120s

echo
echo "==> Usuário: admin"
echo -n "==> Senha:   "
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || \
  echo "(secret argocd-initial-admin-secret não encontrado — senha já pode ter sido alterada)"
echo
echo
echo "==> Acesse: http://localhost:${PORT}"
echo "==> (requer o argocd-server em modo insecure — veja enable-insecure-argo.sh)"
echo "==> Ctrl+C para encerrar."
echo

# 8081 (host) -> 80 (http do argocd-server)
kubectl port-forward svc/argocd-server -n argocd "${PORT}:80"
