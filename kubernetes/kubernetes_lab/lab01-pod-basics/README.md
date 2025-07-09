# Lab 01: Creating Your First Pod

## Objectives
- Understand what a Pod is in Kubernetes
- Learn how to write a basic Pod manifest (YAML)
- Deploy a Pod to your cluster using `kubectl`
- Inspect Pod status and logs

## Prerequisites
- Access to a Kubernetes cluster (e.g., Minikube, Kind, or cloud provider)
- `kubectl` installed and configured

## Instructions

### 1. Study: What is a Pod?
- A Pod is the smallest deployable unit in Kubernetes. It can contain one or more containers.
- Read: [Kubernetes Pods Overview](https://kubernetes.io/docs/concepts/workloads/pods/)

### 2. Write a Pod Manifest
- Create a file named `pod.yaml` in this directory.
- The Pod should run the `nginx` container (use image: `nginx:latest`).
- Name the Pod `nginx-pod`.
- Example structure (do not copy-paste, try to write it yourself!):
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: <your-pod-name>
  spec:
    containers:
    - name: <container-name>
      image: <container-image>
  ```

### 3. Deploy the Pod
- Run: `kubectl apply -f pod.yaml`
- Check status: `kubectl get pods`
- View details: `kubectl describe pod nginx-pod`
- View logs: `kubectl logs nginx-pod`

### 4. Clean Up
- Delete the Pod: `kubectl delete -f pod.yaml`

## Troubleshooting
- If your Pod is not running, check the output of `kubectl describe pod <pod-name>` for errors.
- Use `kubectl get events` to see recent cluster events.
- Make sure your cluster is running and `kubectl` is configured correctly.

## Study Resources
- [Pods - Kubernetes Docs](https://kubernetes.io/docs/concepts/workloads/pods/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Interactive Tutorial: Creating a Pod](https://kubernetes.io/docs/tutorials/kubernetes-basics/create-pod/create-interactive/) 