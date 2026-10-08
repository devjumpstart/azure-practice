# n8n on Azure Kubernetes Service

A production-style deployment of [n8n](https://n8n.io/) on Azure Kubernetes Service (AKS), built with Terraform and Kubernetes.

The goal of this project was not simply to get n8n running. I wanted to build the surrounding infrastructure properly: external PostgreSQL, centralized secret management, persistent storage, ingress, TLS, and a repeatable deployment workflow.

## Architecture

```mermaid
flowchart TD
    User[User] --> CF[Cloudflare DNS / Proxy]
    CF --> TR[Traefik Ingress Controller]
    TR --> ING[n8n Ingress]
    ING --> SVC[n8n ClusterIP Service]
    SVC --> POD[n8n Pod]

    POD --> PVC[PersistentVolumeClaim]
    POD --> PG[Azure PostgreSQL Flexible Server]

    POD --> CSI[Secrets Store CSI Driver]
    CSI --> KV[Azure Key Vault]

    CM[cert-manager] --> LE[Let's Encrypt]
    CM --> ING

    TF[Terraform] --> AKS[Azure Kubernetes Service]
    TF --> PG
    TF --> KV
    TF --> RBAC[Azure RBAC / Managed Identity]

    AKS --> POD