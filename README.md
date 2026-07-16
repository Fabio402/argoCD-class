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
