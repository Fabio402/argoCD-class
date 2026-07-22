# ArgoCD Class — NestJS API no Minikube

API base em NestJS com deploy em dois ambientes (`master` e `dev`) via Kustomize, com autoscaling (HPA) por CPU e memória no ambiente `master`.

## Estrutura

```
app/                        # API NestJS + Dockerfile
manifests/
  base/                     # Deployment + Service (comum aos ambientes)
  overlays/
    dev/                    # namespace nest-api-dev, tag dev, 1 réplica
    master/                 # namespace nest-api-master, tag master, HPA (CPU 70% / memória 80%)
application.yaml            # 2 Applications do ArgoCD (uma por branch)
deploy.sh                   # Deploy manual via kubectl (sem ArgoCD)
```

## Deploy rápido

```bash
minikube start
./deploy.sh          # deploya dev e master
./deploy.sh master   # ou apenas um ambiente
```

O script habilita o `metrics-server`, builda a imagem dentro do daemon Docker do minikube (`eval $(minikube docker-env)`) e aplica os overlays com `kubectl apply -k`.

## Testando

```bash
kubectl port-forward svc/nest-api 8080:80 -n nest-api-master
curl http://localhost:8080/          # info do ambiente
curl http://localhost:8080/health    # health check
curl http://localhost:8080/load     # gera carga de CPU (para testar o HPA)
```

Gerar carga contínua para ver o HPA escalar:

```bash
while true; do curl -s http://localhost:8080/load > /dev/null; done
kubectl get hpa -n nest-api-master -w
```

## Observando com o k9s

```bash
k9s -n nest-api-master
```

Atalhos úteis: `:pods`, `:hpa`, `:deploy`, `l` (logs), `d` (describe), `0` (todos os namespaces).

## Versionamento por branch (GitOps)

Cada branch tem sua Application no ArgoCD (`application.yaml`):

| Branch  | Overlay                     | Namespace         | Escala                 |
|---------|-----------------------------|-------------------|------------------------|
| master  | `manifests/overlays/master` | `nest-api-master` | HPA 2–6 (CPU/memória)  |
| dev     | `manifests/overlays/dev`    | `nest-api-dev`    | 1 réplica fixa         |

Para usar com ArgoCD:

```bash
kubectl apply -f application.yaml
```

O ArgoCD sincroniza automaticamente (`automated`, `prune`, `selfHeal`) cada namespace com a respectiva branch do repositório.

## Acessando a UI do ArgoCD (porta 8081)

O `argocd-server` é `ClusterIP` (não exposto para fora). Para abrir no navegador em HTTP puro na porta 8081:

```bash
./enable-insecure-argo.sh   # 1x por cluster: aplica server.insecure e reinicia o server
./access-argo.sh            # port-forward 8081 -> 80 e mostra a senha do admin
# abra http://localhost:8081  (usuário: admin)
```

- `argocd/argocd-cmd-params-cm.yaml` versiona o `server.insecure: "true"` (HTTP sem redirect para HTTPS).
- Válido só para ambiente local/aula — em produção, use Ingress com TLS.
- O `port-forward` cai ao fechar o terminal ou reiniciar; rode `./access-argo.sh` de novo.

## Rollback automático por taxa de erro (Argo Rollouts)

O ArgoCD sozinho não faz rollback baseado em métricas — ele só reconcilia o Git. Quem faz isso é o **Argo Rollouts**, que no overlay `main` substitui o `Deployment` por um `Rollout` canary com análise via Prometheus.

Como funciona a cada nova versão sincronizada no `main`:

1. O `Rollout` sobe a nova versão gradualmente (25% → 50% → 100%, com pausas).
2. Em paralelo, a `AnalysisTemplate` `error-rate` consulta o Prometheus a cada 30s:
   `sum(rate(http_requests_total{status=~"5.."}[1m])) / sum(rate(http_requests_total[1m]))`.
3. Se a taxa de erro **≥ 20%**, a análise falha, o rollout é **abortado** e o Rollouts **volta automaticamente para a versão estável anterior**.

Instalação do controller (Application dedicada):

```bash
kubectl apply -f rollouts.yaml
```

Testando o rollback:

```bash
# gera 5xx contínuos para estourar os 20%
kubectl port-forward svc/nest-api 8080:80 -n nest-api-main
while true; do curl -s http://localhost:8080/error > /dev/null; done

# acompanhe o rollout abortar e voltar à versão estável
kubectl argo rollouts get rollout nest-api -n nest-api-main --watch
```

> O HPA no `main` mira o `Rollout` (`scaleTargetRef.kind: Rollout`), não mais o `Deployment`.
