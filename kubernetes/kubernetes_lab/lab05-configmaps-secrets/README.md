# Lab 05: ConfigMaps and Secrets

## Objectives
- Understand what ConfigMaps and Secrets are in Kubernetes
- Learn how to create and use ConfigMaps and Secrets in Pods
- Inject configuration and sensitive data into your applications

## Prerequisites
- Completed Lab 04: Exposing Applications with Services
- Access to a Kubernetes cluster and `kubectl`

## Instructions

### 1. Study: What are ConfigMaps and Secrets?
- ConfigMaps are used to store non-confidential configuration data.
- Secrets are used to store sensitive information, such as passwords or tokens.
- Read: [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/) and [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

### 2. Create a ConfigMap
- Create a file named `configmap.yaml` in this directory.
- Define a ConfigMap with at least one key-value pair (e.g., `APP_COLOR=blue`).
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  # Add your key-value pairs here
  example.property: "value"
```
- Apply it: `kubectl apply -f configmap.yaml`
- View it: `kubectl get configmaps` and `kubectl describe configmap <name>`

### 3. Create a Secret
- Create a file named `secret.yaml` in this directory.
- Define a Secret with at least one key-value pair (e.g., `DB_PASSWORD=yourpassword`).
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
data:
    DB_PASSWORD=yourpassword (BASE 64)
```
- Apply it: `kubectl apply -f secret.yaml`
- View it: `kubectl get secrets` and `kubectl describe secret <name>`

### 4. Use ConfigMap and Secret in a Pod
- Modify or create a Pod manifest to use the ConfigMap and Secret as environment variables or mounted files.
- Deploy the Pod and verify the values are available inside the container.

### 5. Clean Up
- Delete the ConfigMap, Secret, and Pod: `kubectl delete -f <file>.yaml`

## Troubleshooting
- If values are not injected, check the manifest structure and key names.
- Use `kubectl describe` to inspect resources and events.
- Ensure base64 encoding for Secret values if required.

## Study Resources
- [ConfigMaps - Kubernetes Docs](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets - Kubernetes Docs](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Configure a Pod to Use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Configure a Pod to Use a Secret](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/) 