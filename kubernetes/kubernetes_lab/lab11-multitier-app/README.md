# Lab 11: Multi-tier Application Deployment

## Objectives
- Understand how to deploy a multi-tier (multi-service) application in Kubernetes
- Learn about service discovery and inter-service communication
- Manage dependencies between frontend, backend, and database components

## Prerequisites
- Completed Lab 10: RBAC and Security
- Access to a Kubernetes cluster and `kubectl`

## Instructions

### 1. Study: What is a Multi-tier Application?
- A multi-tier app consists of multiple services (e.g., frontend, backend, database) that communicate with each other.
- Read: [Example: Deploying WordPress and MySQL with Kubernetes](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/)

### 2. Plan Your Application
- Choose a simple stack (e.g., frontend: nginx, backend: simple API, database: MySQL or PostgreSQL).
- Define how services will communicate (e.g., backend connects to database, frontend connects to backend).

### 3. Write Manifests for Each Component
- Create separate YAML files for each component (e.g., `frontend-deployment.yaml`, `backend-deployment.yaml`, `db-deployment.yaml`).
- Expose each component with a Service (ClusterIP for internal, NodePort/LoadBalancer for external access).
- Use environment variables or ConfigMaps/Secrets for configuration.

### 4. Deploy the Application
- Apply all manifests: `kubectl apply -f <file>.yaml`
- Verify all Pods and Services are running: `kubectl get pods,svc`

### 5. Test Inter-service Communication
- Use `kubectl exec` to access Pods and test connectivity (e.g., backend can reach database, frontend can reach backend).
- Access the frontend externally if exposed.

### 6. Clean Up
- Delete all resources: `kubectl delete -f <file>.yaml`

## Troubleshooting
- If services can't communicate, check Service selectors, environment variables, and DNS names.
- Use `kubectl logs` and `kubectl describe` for debugging.
- Ensure all dependencies are running before starting dependent services.

## Study Resources
- [Kubernetes Multi-tier App Example](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/)
- [Connecting Applications with Services](https://kubernetes.io/docs/concepts/services-networking/connect-applications-service/)
- [Kubernetes DNS for Service Discovery](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) 