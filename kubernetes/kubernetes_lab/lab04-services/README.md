# Lab 04: Exposing Applications with Services

## Objectives
- Understand what a Service is in Kubernetes
- Learn about ClusterIP, NodePort, and LoadBalancer types
- Expose a Deployment using a Service

## Prerequisites
- Completed Lab 03: Deployments
- Access to a Kubernetes cluster and `kubectl`

## Instructions

### 1. Study: What is a Service?
- A Service exposes your application to network traffic inside or outside the cluster.
- Read: [Kubernetes Services Overview](https://kubernetes.io/docs/concepts/services-networking/service/)

### 2. Write a Service Manifest
- Create a file named `service.yaml` in this directory.
- The Service should expose the `nginx-deployment` from the previous lab.
- Try creating a ClusterIP Service first, then modify it to NodePort or LoadBalancer if your environment supports it.
- Example structure (write it yourself!):
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: <your-service-name>
  spec:
    type: <service-type>
    selector:
      app: <label>
    ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  ```

### 3. Deploy the Service
- Run: `kubectl apply -f service.yaml`
- Check status: `kubectl get services`
- Get the Service's ClusterIP or external IP (if using NodePort/LoadBalancer)

### 4. Access the Application
- For ClusterIP: Use `kubectl port-forward service/<your-service-name> 8080:80` to access the service locally.
- For NodePort/LoadBalancer: Access via the node's IP and assigned port.

### 5. Clean Up
- Delete the Service: `kubectl delete -f service.yaml`

## Troubleshooting
- If you can't access your app, check the Service type and port configuration.
- Use `kubectl describe service <name>` and `kubectl get endpoints <name>` for debugging.
- Ensure your Deployment is running and labeled correctly.

## Study Resources
- [Services - Kubernetes Docs](https://kubernetes.io/docs/concepts/services-networking/service/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Accessing Applications in Kubernetes](https://kubernetes.io/docs/tasks/access-application-cluster/) 