# Lab 03: Deployments

## Objectives
- Understand what a Deployment is and its benefits
- Learn how to write a Deployment manifest
- Perform rolling updates and rollbacks

## Prerequisites
- Completed Lab 02: Working with ReplicaSets
- Access to a Kubernetes cluster and `kubectl`

## Instructions

### 1. Study: What is a Deployment?
- A Deployment provides declarative updates for Pods and ReplicaSets.
- Read: [Kubernetes Deployment Overview](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

### 2. Write a Deployment Manifest
- Create a file named `deployment.yaml` in this directory.
- The Deployment should manage 3 replicas of an `nginx` Pod.
- Name the Deployment `nginx-deployment`.
- Example structure (write it yourself!):
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: <your-deployment-name>
  spec:
    replicas: <number-of-replicas>
    selector:
      matchLabels:
        app: <label>
    template:
      metadata:
        labels:
          app: <label>
      spec:
        containers:
        - name: <container-name>
          image: <container-image>
  ```

### 3. Deploy the Deployment
- Run: `kubectl apply -f deployment.yaml`
- Check status: `kubectl get deployments`
- Check Pods: `kubectl get pods -l app=<label>`

### 4. Perform a Rolling Update
- Edit `deployment.yaml` to use a different image tag (e.g., `nginx:1.19` to `nginx:1.20`).
- Apply the change: `kubectl apply -f deployment.yaml`
- Observe the rolling update: `kubectl rollout status deployment/nginx-deployment`

### 5. Rollback the Deployment
- Rollback to the previous version: `kubectl rollout undo deployment/nginx-deployment`

### 6. Clean Up
- Delete the Deployment: `kubectl delete -f deployment.yaml`

## Troubleshooting
- If Pods are not updated, check the image tag and manifest structure.
- Use `kubectl describe deployment <name>` and `kubectl get events` for debugging.
- For rollout issues: `kubectl rollout status deployment/<name>`

## Study Resources
- [Deployment - Kubernetes Docs](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Rolling Updates and Rollbacks](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#updating-a-deployment) 