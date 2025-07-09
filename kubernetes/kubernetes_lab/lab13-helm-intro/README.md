# Lab 13: Introduction to Helm

## Objectives
- Understand what Helm is and why it is used in Kubernetes
- Learn about Helm charts, repositories, and releases
- Install and use Helm to deploy applications

## Prerequisites
- Completed Lab 12: CI/CD Integration
- Access to a Kubernetes cluster and `kubectl`
- Helm installed ([installation guide](https://helm.sh/docs/intro/install/))

## Instructions

### 1. Study: What is Helm?
- Helm is a package manager for Kubernetes, simplifying deployment and management of applications.
- Read: [Helm Overview](https://helm.sh/docs/intro/using_helm/)

### 2. Install Helm (if not already installed)
- Follow the [official installation guide](https://helm.sh/docs/intro/install/).
- Verify installation: `helm version`

### 3. Add a Helm Repository
- Add the official stable charts repo: `helm repo add bitnami https://charts.bitnami.com/bitnami`
- Update repo: `helm repo update`

### 4. Search for a Chart
- Search for nginx: `helm search repo nginx`

### 5. Install a Chart
- Install nginx: `helm install my-nginx bitnami/nginx`
- Check release: `helm list`
- Check resources: `kubectl get all`

### 6. Uninstall a Release
- Uninstall: `helm uninstall my-nginx`

## Troubleshooting
- If installation fails, check Helm and Kubernetes versions.
- Use `helm status <release>` and `kubectl describe` for debugging.
- Ensure your cluster is running and `kubectl` is configured.

## Study Resources
- [Helm Documentation](https://helm.sh/docs/)
- [Helm Quickstart Guide](https://helm.sh/docs/intro/quickstart/)
- [Helm Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/) 