# Lab 10: RBAC and Security

## Objectives
- Understand Role-Based Access Control (RBAC) in Kubernetes
- Learn how to create Roles, RoleBindings, ClusterRoles, and ClusterRoleBindings
- Explore ServiceAccounts and NetworkPolicies for security

## Prerequisites
- Completed Lab 09: Monitoring and Logging
- Access to a Kubernetes cluster and `kubectl`

## Instructions

### 1. Study: What is RBAC?
- RBAC controls who can perform actions on resources in your cluster.
- Read: [RBAC Overview](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

### 2. Create a Role and RoleBinding
- Create a file named `role.yaml` to define a Role with limited permissions (e.g., read Pods) in a namespace.
- Create a file named `rolebinding.yaml` to bind the Role to a user or ServiceAccount.
- Apply both files and test access.

### 3. Create a ClusterRole and ClusterRoleBinding
- Create a file named `clusterrole.yaml` for cluster-wide permissions.
- Create a file named `clusterrolebinding.yaml` to bind the ClusterRole.
- Apply and test access at the cluster level.

### 4. Use ServiceAccounts
- Create a file named `serviceaccount.yaml` and assign it to a Pod.
- Test Pod permissions using the ServiceAccount.

### 5. Apply a NetworkPolicy
- Create a file named `networkpolicy.yaml` to restrict traffic between Pods.
- Apply and test connectivity.

### 6. Clean Up
- Delete all created RBAC and security resources: `kubectl delete -f <file>.yaml`

## Troubleshooting
- If access is denied, check Role/RoleBinding and ClusterRole/ClusterRoleBinding definitions.
- Use `kubectl auth can-i` to test permissions.
- For NetworkPolicies, ensure your cluster supports them and check Pod labels/selectors.

## Study Resources
- [RBAC - Kubernetes Docs](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/overview/) 