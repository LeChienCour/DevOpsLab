# Lab 09: Monitoring and Logging

## Objectives
- Understand the importance of monitoring and logging in Kubernetes
- Learn how to deploy basic monitoring (Prometheus, Grafana)
- Learn how to deploy basic logging (EFK/ELK stack)
- Explore built-in Kubernetes monitoring and logging tools

## Prerequisites
- Completed Lab 08: Ingress Controllers
- Access to a Kubernetes cluster and `kubectl`

## Instructions

### 1. Study: Why Monitor and Log?
- Monitoring helps you track cluster health and resource usage.
- Logging helps you debug and audit workloads.
- Read: [Monitoring Overview](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/), [Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/)

### 2. Deploy Prometheus and Grafana (Monitoring)
- Use Helm or manifests to deploy Prometheus and Grafana (see study resources for guides).
- Access Grafana and add Prometheus as a data source.
- Explore cluster metrics and create a simple dashboard.

### 3. Deploy EFK/ELK Stack (Logging)
- Deploy Elasticsearch, Fluentd, and Kibana (or use a managed solution).
- Send Pod logs to Elasticsearch using Fluentd.
- Access Kibana and explore logs from your applications.

### 4. Explore Built-in Tools
- Use `kubectl top nodes` and `kubectl top pods` for resource metrics (requires Metrics Server).
- Use `kubectl logs <pod>` for basic log access.

### 5. Clean Up
- Uninstall monitoring and logging stacks using Helm or `kubectl delete`.

## Troubleshooting
- If dashboards or logs are empty, check that all Pods are running and Services are accessible.
- Use `kubectl get pods`, `kubectl describe pod <name>`, and check logs for errors.
- Ensure correct RBAC permissions for monitoring/logging components.

## Study Resources
- [Kubernetes Monitoring with Prometheus](https://kubernetes.io/docs/tasks/debug/debug-cluster/prometheus/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Grafana Docs](https://grafana.com/docs/)
- [Kubernetes Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/)
- [EFK Stack on Kubernetes](https://kubernetes.io/docs/tasks/debug/debug-cluster/logging-elasticsearch-kibana/) 