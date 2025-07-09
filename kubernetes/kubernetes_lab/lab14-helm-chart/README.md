# Lab 14: Creating Your First Helm Chart

## Objectives
- Learn the structure of a Helm chart
- Create a custom Helm chart for a simple application
- Package and deploy your chart to Kubernetes

## Prerequisites
- Completed Lab 13: Introduction to Helm
- Access to a Kubernetes cluster and `kubectl`
- Helm installed

## Instructions

### 1. Study: Helm Chart Structure
- Charts are collections of files describing a related set of Kubernetes resources.
- Read: [Chart Structure](https://helm.sh/docs/topics/charts/)

### 2. Create a New Chart
- Run: `helm create mychart`
- Explore the generated directory structure and files (`Chart.yaml`, `values.yaml`, `templates/`, etc.)

### 3. Customize Your Chart
- Edit `values.yaml` to set custom values (e.g., image, replica count).
- Edit templates in `templates/` to modify resources as needed.

### 4. Install Your Chart
- Deploy: `helm install myapp ./mychart`
- Check resources: `kubectl get all`

### 5. Upgrade and Rollback
- Change a value in `values.yaml` (e.g., replica count) and upgrade: `helm upgrade myapp ./mychart`
- Rollback if needed: `helm rollback myapp 1`

### 6. Package Your Chart
- Run: `helm package mychart` to create a `.tgz` package

### 7. Clean Up
- Uninstall: `helm uninstall myapp`

## Troubleshooting
- If deployment fails, check template syntax and values.
- Use `helm status <release>` and `kubectl describe` for debugging.
- Ensure all required fields are set in `values.yaml` and `Chart.yaml`.

## Study Resources
- [Helm Chart Template Guide](https://helm.sh/docs/chart_template_guide/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Helm Docs: Creating Charts](https://helm.sh/docs/topics/charts/) 