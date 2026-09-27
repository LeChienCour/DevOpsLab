# Lab 19: Troubleshooting

## Introduction
Troubleshooting is a major part of the CKA exam (approx. 30%). You need to be able to diagnose and fix issues with clusters, nodes, and pods. In this lab, you will practice debugging common scenarios.

## Learning Objectives
- Debug Pods in `Pending`, `CrashLoopBackOff`, and `ImagePullBackOff` states.
- Debug Service connectivity issues.
- Debug Node NotReady status.

## Prerequisites
- A running Kubernetes cluster.
- `kubectl` configured.

## Instructions

### Scenario 1: Pod Pending
1. Create a pod that requests too many resources:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: big-pod
   spec:
     containers:
     - name: nginx
       image: nginx
       resources:
         requests:
           memory: "100Gi"
   ```
   Save as `big-pod.yaml` and apply.

2. Check status:
   ```bash
   kubectl get pod big-pod
   ```
   Status should be `Pending`.

3. Investigate:
   ```bash
   kubectl describe pod big-pod
   ```
   Look at the "Events" section. You should see "Insufficient memory".

4. Fix:
   Edit the pod to request less memory (e.g., "100Mi") and re-apply (or delete and re-create).

### Scenario 2: CrashLoopBackOff
1. Create a pod that exits immediately:
   ```bash
   kubectl run crasher --image=busybox -- sh -c "exit 1"
   ```

2. Check status:
   ```bash
   kubectl get pod crasher
   ```
   Status will cycle between `Error` and `CrashLoopBackOff`.

3. Investigate:
   ```bash
   kubectl logs crasher
   ```
   (Might be empty if it crashed too fast or didn't log anything)
   
   ```bash
   kubectl describe pod crasher
   ```
   Check "Last State" and "Exit Code".

4. Fix:
   Update the command to something that runs forever, e.g., `sleep 3600`.

### Scenario 3: ImagePullBackOff
1. Create a pod with a non-existent image:
   ```bash
   kubectl run wrong-image --image=nginx:nonexistenttag
   ```

2. Check status:
   ```bash
   kubectl get pod wrong-image
   ```
   Status: `ImagePullBackOff` or `ErrImagePull`.

3. Investigate:
   ```bash
   kubectl describe pod wrong-image
   ```
   Events will show "Failed to pull image".

4. Fix:
   Edit the pod to use a valid image tag (e.g., `nginx:latest`).

### Scenario 4: Service Connectivity
1. Create a deployment:
   ```bash
   kubectl create deployment web --image=nginx --replicas=2
   ```

2. Create a service with the WRONG selector:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: web-service
   spec:
     selector:
       app: wrong-label
     ports:
     - protocol: TCP
       port: 80
       targetPort: 80
   ```
   Save as `web-service.yaml` and apply.

3. Test connectivity (will fail):
   ```bash
   kubectl run test --image=busybox --rm -it -- wget -O- http://web-service
   ```

4. Investigate:
   Check Endpoints:
   ```bash
   kubectl get endpoints web-service
   ```
   It should show `<none>`.

   Check Pod labels:
   ```bash
   kubectl get pods --show-labels
   ```

5. Fix:
   Edit the service to match the pod labels (`app: web`).
   ```bash
   kubectl edit service web-service
   ```

### Scenario 5: Node Troubleshooting (Conceptual)
In a real exam, you might find a node in `NotReady` state.
1. Check node status:
   ```bash
   kubectl get nodes
   ```

2. Describe node:
   ```bash
   kubectl describe node <node-name>
   ```
   Look for "Conditions" (DiskPressure, PIDPressure, MemoryPressure, Ready).

3. Check Kubelet service (on the node):
   ```bash
   systemctl status kubelet
   journalctl -u kubelet
   ```

## Clean Up
```bash
kubectl delete pod big-pod crasher wrong-image
kubectl delete deployment web
kubectl delete service web-service
```
