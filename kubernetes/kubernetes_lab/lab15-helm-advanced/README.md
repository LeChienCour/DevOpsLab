# Lab 15: Advanced Helm Usage

## Objectives
- Learn about advanced Helm features: dependencies, hooks, and lifecycle
- Manage chart dependencies and subcharts
- Use hooks for pre/post-install tasks
- Handle upgrades and rollbacks

## Prerequisites
- Completed Lab 14: Creating Your First Helm Chart
- Access to a Kubernetes cluster and `kubectl`
- Helm installed

## Instructions

### 1. Study: Advanced Helm Concepts
- Read about [Chart Dependencies](https://helm.sh/docs/topics/charts/#chart-dependencies), [Hooks](https://helm.sh/docs/topics/charts_hooks/), and [Chart Lifecycle](https://helm.sh/docs/topics/charts_hooks/#the-chart-lifecycle)

### 2. Add a Dependency to Your Chart
- In your chart, edit `Chart.yaml` to add a dependency (e.g., Redis subchart).
- Run: `helm dependency update` to fetch dependencies.
- Install your chart and verify subcharts are deployed.

### 3. Use Helm Hooks
- Add a hook annotation to a template (e.g., pre-install or post-install job).
- Deploy and observe hook execution.

### 4. Handle Upgrades and Rollbacks
- Upgrade your release with new values or templates.
- Rollback to a previous release if needed.

### 5. Clean Up
- Uninstall your release: `helm uninstall <release>`

## Troubleshooting
- If dependencies are not installed, check `Chart.yaml` and run `helm dependency update`.
- For hooks, check annotation syntax and hook logs.
- Use `helm history <release>` and `helm rollback` for troubleshooting upgrades.

## Study Resources
- [Helm Chart Dependencies](https://helm.sh/docs/topics/charts/#chart-dependencies)
- [Helm Hooks](https://helm.sh/docs/topics/charts_hooks/)
- [Helm Upgrade and Rollback](https://helm.sh/docs/helm/helm_upgrade/)
- [Helm Docs](https://helm.sh/docs/) 