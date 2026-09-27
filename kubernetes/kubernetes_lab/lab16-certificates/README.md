# Lab 16: Certificates and TLS Management

## Introduction
In this lab, you will learn how to manage TLS certificates in a Kubernetes cluster. This is a critical skill for the CKA certification. You will work with Certificate Signing Requests (CSRs), approve them, and understand how to use the generated certificates.

## Learning Objectives
- Understand the certificate signing process in Kubernetes.
- Create a private key and a Certificate Signing Request (CSR).
- Create a `CertificateSigningRequest` object in Kubernetes.
- Approve a CSR using `kubectl`.
- Retrieve the signed certificate.
- Create a kubeconfig file for a new user.

## Prerequisites
- A running Kubernetes cluster (Minikube, Kind, or a cloud provider).
- `kubectl` configured to communicate with your cluster.
- `openssl` installed on your machine.

## Instructions

### Step 1: Create a Private Key and CSR
First, simulate a new user named `jane` who needs access to the cluster.

1. Create a private key for Jane:
   ```bash
   openssl genrsa -out jane.key 2048
   ```

2. Create a Certificate Signing Request (CSR). Note that the Common Name (CN) is important as it represents the user name in Kubernetes:
   ```bash
   openssl req -new -key jane.key -out jane.csr -subj "/CN=jane/O=developers"
   ```

### Step 2: Create a CertificateSigningRequest Object
Now you need to send this CSR to the Kubernetes API Server to be signed by the Cluster Authority (CA).

1. Encode the CSR content to base64:
   ```bash
   cat jane.csr | base64 | tr -d "\n"
   ```

2. Create a file named `jane-csr.yaml` with the following content. Replace `BASE64_CSR_CONTENT` with the output from the previous command:
   ```yaml
   apiVersion: certificates.k8s.io/v1
   kind: CertificateSigningRequest
   metadata:
     name: jane
   spec:
     request: BASE64_CSR_CONTENT
     signerName: kubernetes.io/kube-apiserver-client
     usages:
     - client auth
   ```

3. Apply the YAML to the cluster:
   ```bash
   kubectl apply -f jane-csr.yaml
   ```

### Step 3: Approve the CSR
1. List the CSRs to see the pending request:
   ```bash
   kubectl get csr
   ```

2. Approve the CSR:
   ```bash
   kubectl certificate approve jane
   ```

3. Verify that the CSR is approved:
   ```bash
   kubectl get csr jane
   ```

### Step 4: Retrieve the Signed Certificate
1. Extract the signed certificate from the CSR object:
   ```bash
   kubectl get csr jane -o jsonpath='{.status.certificate}' | base64 --decode > jane.crt
   ```

### Step 5: Create a Kubeconfig for Jane
Now that you have the key and the certificate, you can create a kubeconfig file for Jane.

1. Add credentials for Jane:
   ```bash
   kubectl config set-credentials jane --client-key=jane.key --client-certificate=jane.crt --embed-certs=true
   ```

2. Add a context for Jane:
   ```bash
   kubectl config set-context jane --cluster=minikube --user=jane
   # Note: Replace 'minikube' with your actual cluster name if different.
   ```

3. Test access (it should fail because Jane has no permissions yet):
   ```bash
   kubectl --context=jane get pods
   ```

### Step 6: Grant Permissions (Optional)
To make the user useful, you would typically create a Role and RoleBinding.

1. Create a RoleBinding to give Jane view access to the default namespace:
   ```bash
   kubectl create rolebinding jane-view --clusterrole=view --user=jane --namespace=default
   ```

2. Test access again:
   ```bash
   kubectl --context=jane get pods
   ```

## Clean Up
```bash
kubectl delete csr jane
kubectl delete rolebinding jane-view
kubectl config delete-context jane
kubectl config delete-user jane
rm jane.key jane.csr jane.crt jane-csr.yaml
```
