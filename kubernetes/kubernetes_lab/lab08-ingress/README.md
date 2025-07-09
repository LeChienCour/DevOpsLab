# Lab 08: Ingress Controllers

## Objectives
- Understand what Ingress and Ingress Controllers are
- Learn how to expose HTTP/S services using Ingress
- Configure basic routing rules

## Prerequisites
- Completed Lab 07: Namespaces and Resource Quotas
- Access to a Kubernetes cluster and `kubectl`
- An Ingress Controller installed (e.g., NGINX Ingress Controller)

## Instructions

### 1. Study: What is Ingress?
- Ingress manages external access to services in a cluster, typically HTTP.
- Read: [Ingress Overview](https://kubernetes.io/docs/concepts/services-networking/ingress/)

### 2. Install an Ingress Controller (if not already installed)
- For Minikube: `minikube addons enable ingress`
- For other clusters, follow the [NGINX Ingress Controller installation guide](https://kubernetes.github.io/ingress-nginx/deploy/)

### 3. Create a Service and Deployment
- Use a simple web app (e.g., `nginx` or `http-echo`).
- Deploy the app and expose it with a ClusterIP Service.

### 4. Write an Ingress Resource
- Create a file named `ingress.yaml` in this directory.
- Define an Ingress resource to route HTTP traffic to your Service based on the host or path.
- Example structure (write it yourself!):
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: <your-ingress-name>
  spec:
    rules:
    - host: <your-host>
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: <your-service-name>
              port:
                number: 80
  ```
- Apply it: `kubectl apply -f ingress.yaml`
- View it: `kubectl get ingress`

### 5. Test Ingress Access
- Update your `/etc/hosts` file (or Windows equivalent) to point the test host to your cluster IP if needed.
- Access the app via the defined host/path in your browser or with `curl`.

### 6. Clean Up
- Delete the Ingress, Service, and Deployment: `kubectl delete -f <file>.yaml`

## Troubleshooting
- If Ingress is not working, check that the Ingress Controller is running.
- Use `kubectl describe ingress <name>` and `kubectl get events` for debugging.
- Check Service and Pod status to ensure the backend is healthy.

## Study Resources
- [Ingress - Kubernetes Docs](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [NGINX Ingress Controller Docs](https://kubernetes.github.io/ingress-nginx/)
- [Ingress Tutorial](https://kubernetes.io/docs/tasks/access-application-cluster/ingress-minikube/) 