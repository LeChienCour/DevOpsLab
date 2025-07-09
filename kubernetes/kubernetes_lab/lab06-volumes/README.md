# Lab 06: Volumes and Persistent Storage

## Objectives
- Understand the concept of Volumes in Kubernetes
- Learn how to use different types of Volumes (emptyDir, hostPath, PersistentVolume, PersistentVolumeClaim)
- Attach persistent storage to your Pods
- Learn how to use StatefulSets for stateful applications with persistent storage

## Prerequisites
- Completed Lab 05: ConfigMaps and Secrets
- Access to a Kubernetes cluster and `kubectl`

## Instructions

### 1. Study: What are Volumes?
- Volumes provide storage for data used by containers in a Pod.
- Read: [Volumes Overview](https://kubernetes.io/docs/concepts/storage/volumes/)

### 2. Use an emptyDir Volume
- Create a Pod manifest (`emptydir-pod.yaml`) that uses an `emptyDir` volume.
- Mount the volume into a container and write/read files to/from it.

### 3. Use a hostPath Volume (optional, for local clusters)
- Create a Pod manifest (`hostpath-pod.yaml`) that uses a `hostPath` volume to mount a directory from the node.
- **Note:** Only use this in a local or test environment.

### 4. Use PersistentVolume and PersistentVolumeClaim
- Create a `persistentvolume.yaml` and `persistentvolumeclaim.yaml`.
- Bind a Pod to the PersistentVolume using the PersistentVolumeClaim.
- Verify data persists after Pod restarts.

### 5.
- Study: [StatefulSets Overview](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- Create a `statefulset.yaml` manifest for a simple stateful application (e.g., `nginx` or `mysql`).
- Use a PersistentVolumeClaim template in the StatefulSet to provide each Pod with its own persistent storage.
- Deploy the StatefulSet: `kubectl apply -f statefulset.yaml`
- Check the created Pods and their associated PersistentVolumeClaims: `kubectl get pods`, `kubectl get pvc`
- Delete a Pod and observe that its data persists when recreated.

### 6. Clean Up
- Delete all created resources: `kubectl delete -f <file>.yaml`

## Troubleshooting
- If volumes are not mounted, check the manifest structure and paths.
- Use `kubectl describe pod <name>` and `kubectl get events` for debugging.
- For PersistentVolumes, ensure the storage class and access modes are compatible.
- For StatefulSets, ensure the volumeClaimTemplates are correctly defined and storage is available.

## Study Resources
- [Volumes - Kubernetes Docs](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Configure a Pod to Use a PersistentVolume](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/)
- [StatefulSets - Kubernetes Docs](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [StatefulSet Basics](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/) 