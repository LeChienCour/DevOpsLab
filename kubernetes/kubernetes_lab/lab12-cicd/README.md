# Lab 12: CI/CD Integration

## Objectives
- Understand how to automate Kubernetes deployments with CI/CD
- Learn about popular CI/CD tools for Kubernetes (e.g., ArgoCD, Jenkins X, GitHub Actions)
- Set up a basic CI/CD pipeline to deploy to your cluster

## Prerequisites
- Completed Lab 11: Multi-tier Application Deployment
- Access to a Kubernetes cluster and `kubectl`
- A Git repository for your manifests

## Instructions

### 1. Study: What is CI/CD?
- CI/CD automates building, testing, and deploying applications.
- Read: [CI/CD Concepts](https://kubernetes.io/docs/concepts/cluster-administration/cicd/)

### 2. Choose a CI/CD Tool
- Options include ArgoCD, Jenkins X, GitHub Actions, GitLab CI, etc.
- For this lab, you can use GitHub Actions or ArgoCD for simplicity.

### 3. Set Up a Basic Pipeline
- For GitHub Actions: Create a `.github/workflows/deploy.yaml` in your repo to build, push, and deploy manifests to your cluster.
- For ArgoCD: Install ArgoCD in your cluster and connect it to your Git repo.
- Example steps: checkout code, build/push image, apply manifests with `kubectl` or sync with ArgoCD.

### 4. Trigger a Deployment
- Make a change in your repo and push it to trigger the pipeline.
- Verify the deployment in your cluster: `kubectl get pods,svc`

### 5. Clean Up
- Remove pipeline resources or uninstall ArgoCD if desired.

## Troubleshooting
- If deployments fail, check pipeline logs and Kubernetes events.
- Ensure your cluster credentials are securely managed in your CI/CD tool.
- For ArgoCD, check Application and Sync status in the ArgoCD UI.

## Study Resources
- [CI/CD for Kubernetes](https://kubernetes.io/docs/concepts/cluster-administration/cicd/)
- [GitHub Actions for Kubernetes](https://docs.github.com/en/actions/deployment/deploying-to-your-cloud-provider/deploying-to-kubernetes)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [Jenkins X Documentation](https://jenkins-x.io/docs/) 