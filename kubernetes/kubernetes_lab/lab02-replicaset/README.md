# Lab 02: Working with ReplicaSets

## Objectives
- Understand what a ReplicaSet is and why it is used
- Learn how to write a ReplicaSet manifest
- Deploy and scale Pods using a ReplicaSet
- Update and rollback ReplicaSets

## Prerequisites
- Completed Lab 01: Creating Your First Pod
- Access to a Kubernetes cluster and `kubectl`

## Instructions

### 1. Study: What is a ReplicaSet?
- A ReplicaSet ensures a specified number of Pod replicas are running at all times.
- Read: [Kubernetes ReplicaSet Overview](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)

### 2. Write a ReplicaSet Manifest
- Create a file named `replicaset.yaml` in this directory.
- The ReplicaSet should manage 3 replicas of an `nginx` Pod.
- Name the ReplicaSet `nginx-replicaset`.
- Example structure (write it yourself!):
  ```yaml
  apiVersion: apps/v1
  kind: ReplicaSet
  metadata:
    name: <your-replicaset-name>
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

### 3. Deploy the ReplicaSet
- Run: `kubectl apply -f replicaset.yaml`
- Check status: `kubectl get replicasets`
- Check Pods: `kubectl get pods -l app=<label>`

### 4. Scale the ReplicaSet
- Edit `replicaset.yaml` to change the number of replicas to 5.
- Apply the change: `kubectl apply -f replicaset.yaml`
- Verify the new number of Pods.

### 5. Clean Up
- Delete the ReplicaSet and its Pods: `kubectl delete -f replicaset.yaml`

## Troubleshooting
- If Pods are not created, check the selector and labels in your manifest.
- Use `kubectl describe replicaset <name>` and `kubectl get events` for debugging.

## Study Resources
- [ReplicaSet - Kubernetes Docs](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/) 