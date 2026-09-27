# Lab 17: Network Policies

## Introduction
Network Policies are crucial for securing traffic between pods in a Kubernetes cluster. By default, all pods can communicate with each other. In this lab, you will learn how to restrict traffic using `NetworkPolicy` resources.

## Learning Objectives
- Understand the default network behavior in Kubernetes.
- Create a `NetworkPolicy` to deny all traffic.
- Allow traffic only from specific pods (Ingress).
- Allow traffic only to specific destinations (Egress).

## Prerequisites
- A running Kubernetes cluster with a CNI plugin that supports Network Policies (e.g., Calico, Cilium, Weave Net). **Note: Minikube with default CNI does NOT support Network Policies.** You may need to start minikube with `--cni=calico`.
- `kubectl` configured.

## Instructions

### Step 1: Setup Environment
Create a namespace and some pods to test connectivity.

1. Create a namespace:
   ```bash
   kubectl create ns policy-lab
   ```

2. Create a frontend pod:
   ```bash
   kubectl run frontend --image=nginx --namespace=policy-lab --labels=app=frontend
   ```

3. Create a backend pod:
   ```bash
   kubectl run backend --image=nginx --namespace=policy-lab --labels=app=backend --port=80
   ```

4. Create a database pod:
   ```bash
   kubectl run db --image=nginx --namespace=policy-lab --labels=app=db --port=80
   ```

5. Expose backend and db:
   ```bash
   kubectl expose pod backend --port=80 --namespace=policy-lab
   kubectl expose pod db --port=80 --namespace=policy-lab
   ```

### Step 2: Test Default Connectivity
Verify that all pods can talk to each other.

1. Test frontend to backend:
   ```bash
   kubectl exec -it frontend -n policy-lab -- curl --connect-timeout 2 backend
   ```
   (Should succeed)

2. Test backend to db:
   ```bash
   kubectl exec -it backend -n policy-lab -- curl --connect-timeout 2 db
   ```
   (Should succeed)

### Step 3: Deny All Traffic
Create a "default deny" policy for the namespace.

1. Create `deny-all.yaml`:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: default-deny-all
     namespace: policy-lab
   spec:
     podSelector: {}
     policyTypes:
     - Ingress
     - Egress
   ```

2. Apply the policy:
   ```bash
   kubectl apply -f deny-all.yaml
   ```

3. Test connectivity again (should fail):
   ```bash
   kubectl exec -it frontend -n policy-lab -- curl --connect-timeout 2 backend
   ```

### Step 4: Allow Frontend to Backend
Allow the `backend` pod to receive traffic from `frontend`.

1. Create `allow-frontend-to-backend.yaml`:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: allow-frontend-to-backend
     namespace: policy-lab
   spec:
     podSelector:
       matchLabels:
         app: backend
     policyTypes:
     - Ingress
     ingress:
     - from:
       - podSelector:
           matchLabels:
             app: frontend
       ports:
       - protocol: TCP
         port: 80
   ```

2. Apply the policy:
   ```bash
   kubectl apply -f allow-frontend-to-backend.yaml
   ```

3. Test connectivity:
   - Frontend to Backend: Should succeed (if Egress is not blocked or if we allow Egress from Frontend).
   *Wait, we blocked ALL Egress in Step 3.* We need to allow Egress from Frontend or remove Egress from the deny-all policy for this specific test if we want to be precise, but typically `deny-all` blocks everything.
   
   Let's modify the `deny-all` to only block Ingress for simplicity in this step, OR add an Egress rule for frontend.
   
   Let's add an Egress rule for frontend to talk to backend.

4. Create `allow-frontend-egress.yaml`:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: allow-frontend-egress
     namespace: policy-lab
   spec:
     podSelector:
       matchLabels:
         app: frontend
     policyTypes:
     - Egress
     egress:
     - to:
       - podSelector:
           matchLabels:
             app: backend
       ports:
       - protocol: TCP
         port: 80
   ```

5. Apply Egress rule:
   ```bash
   kubectl apply -f allow-frontend-egress.yaml
   ```

6. Now test Frontend to Backend:
   ```bash
   kubectl exec -it frontend -n policy-lab -- curl --connect-timeout 2 backend
   ```
   (Should succeed)

### Step 5: Clean Up
```bash
kubectl delete ns policy-lab
rm deny-all.yaml allow-frontend-to-backend.yaml allow-frontend-egress.yaml
```
