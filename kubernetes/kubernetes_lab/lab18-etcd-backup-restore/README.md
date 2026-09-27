# Lab 18: ETCD Backup and Restore

## Introduction
ETCD is the brain of Kubernetes, storing all cluster data. Backing up and restoring ETCD is a critical administrative task and a key requirement for the CKA exam. In this lab, you will learn how to take a snapshot of the ETCD database and restore it.

## Learning Objectives
- Understand the importance of ETCD.
- Install `etcdctl`.
- Take a snapshot of ETCD.
- Restore ETCD from a snapshot.

## Prerequisites
- A running Kubernetes cluster where you have access to the ETCD control plane (e.g., Minikube, Kind, or a self-hosted cluster). **Managed Kubernetes services (EKS, GKE, AKS) usually do not give you direct access to ETCD.**
- `kubectl` configured.
- `etcdctl` installed.

## Instructions

### Step 1: Install etcdctl
If you are using Minikube, `etcdctl` might already be inside the minikube container. You can also install it locally.

To install locally (Linux):
```bash
ETCD_VER=v3.5.0
GOOGLE_URL=https://storage.googleapis.com/etcd
curl -L ${GOOGLE_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp
sudo mv /tmp/etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/
rm -rf /tmp/etcd-${ETCD_VER}-linux-amd64
```

### Step 2: Locate ETCD Certificates
ETCD is secured by TLS. You need to find the certificates and keys to authenticate with `etcdctl`.
On most clusters (kubeadm, minikube), they are located in `/etc/kubernetes/pki/etcd`.

Common paths:
- CA Certificate: `/etc/kubernetes/pki/etcd/ca.crt`
- Server Certificate: `/etc/kubernetes/pki/etcd/server.crt`
- Server Key: `/etc/kubernetes/pki/etcd/server.key`

If using Minikube, you can SSH into the node to find them:
```bash
minikube ssh
ls /etc/kubernetes/pki/etcd
exit
```

### Step 3: Take a Snapshot
You need to run this command from a place that has access to the ETCD endpoint (usually localhost:2379 on the control plane) and the certificates.

If using Minikube, it's easiest to run this *inside* the minikube node:

1. SSH into Minikube:
   ```bash
   minikube ssh
   ```

2. Set environment variables for convenience:
   ```bash
   export ETCDCTL_API=3
   export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
   export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
   export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
   ```

3. Verify health:
   ```bash
   etcdctl endpoint health
   ```

4. Take the snapshot:
   ```bash
   etcdctl snapshot save /tmp/snapshot.db
   ```

5. Verify the snapshot:
   ```bash
   etcdctl snapshot status /tmp/snapshot.db
   ```

6. Exit Minikube:
   ```bash
   exit
   ```

### Step 4: Restore from Snapshot
**WARNING: Restoring ETCD will overwrite the current cluster state.**

To simulate a disaster, let's create a pod, delete it, and then restore to the state where it existed (if we took the snapshot when it existed).

1. Create a test pod:
   ```bash
   kubectl run test-pod --image=nginx
   ```

2. Take a snapshot (repeat Step 3).

3. Delete the pod:
   ```bash
   kubectl delete pod test-pod
   ```

4. Restore the snapshot (Inside Minikube/Control Plane):
   ```bash
   minikube ssh
   # Set env vars again if needed
   export ETCDCTL_API=3
   
   # Restore to a new data directory to be safe
   etcdctl snapshot restore /tmp/snapshot.db --data-dir /var/lib/etcd-restore
   ```

5. Update ETCD Configuration:
   You need to tell the ETCD pod to use the new data directory.
   - Edit `/etc/kubernetes/manifests/etcd.yaml`
   - Change `hostPath` for `etcd-data` volume to point to `/var/lib/etcd-restore`.
   
   *Note: In a real exam, you might need to update the static pod manifest or the systemd service file.*

6. Wait for ETCD to restart.

7. Verify the pod is back:
   ```bash
   kubectl get pods
   ```

### Step 5: Clean Up
Revert the changes to `/etc/kubernetes/manifests/etcd.yaml` to point back to the original data directory, or delete the Minikube cluster and start fresh.
