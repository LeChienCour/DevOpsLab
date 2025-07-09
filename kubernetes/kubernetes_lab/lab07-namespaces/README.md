# Lab 07: Namespaces and Resource Quotas

## Objectives
- Understand what Namespaces are and why they are used
- Learn how to create and use Namespaces
- Apply ResourceQuotas and LimitRanges to control resource usage

## Prerequisites
- Completed Lab 06: Volumes and Persistent Storage
- Access to a Kubernetes cluster and `kubectl`

## Instructions

### 1. Study: What are Namespaces?
- Namespaces allow you to divide cluster resources between multiple users or teams.
- Read: [Namespaces Overview](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)

### 2. Create a Namespace
- Create a file named `namespace.yaml` in this directory.
- Define a Namespace called `dev-lab`.
- Apply it: `kubectl apply -f namespace.yaml`
- View it: `kubectl get namespaces`

### 3. Deploy Resources in a Namespace
- Modify a Pod or Deployment manifest to use the `dev-lab` namespace (add `namespace: dev-lab` in metadata or use `-n dev-lab` with kubectl).
- Deploy and verify resources are created in the correct namespace.

### 4. Apply a ResourceQuota
- Create a file named `resourcequota.yaml` in this directory.
- Define a ResourceQuota to limit CPU, memory, or object counts in `dev-lab`.
- Apply it: `kubectl apply -f resourcequota.yaml -n dev-lab`
- View it: `kubectl get resourcequota -n dev-lab`

### 5. Apply a LimitRange
- Create a file named `limitrange.yaml` in this directory.
- Define a LimitRange to set default/request/limit values for Pods in `dev-lab`.
- Apply it: `kubectl apply -f limitrange.yaml -n dev-lab`
- View it: `kubectl get limitrange -n dev-lab`

### 6. Clean Up
- Delete the Namespace (this deletes all resources in it): `kubectl delete namespace dev-lab`

## Troubleshooting
- If resources are not created in the correct namespace, check the manifest and kubectl commands.
- Use `kubectl describe` and `kubectl get events -n <namespace>` for debugging.
- If you hit quota errors, check your ResourceQuota and LimitRange settings.

## Study Resources
- [Namespaces - Kubernetes Docs](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/) 