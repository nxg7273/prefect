# Prefect Server on EKS Fargate Deployment Guide

## Overview
This repository contains configuration and deployment scripts for running Prefect Server on Amazon EKS Fargate with Traefik IngressRoute integration.

## Prerequisites
- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- eksctl installed
- Kubernetes 1.30
- Traefik Ingress Controller with IngressRoute support

## Cluster Configuration
- Cluster Name: protein-engineering-cluster-new
- Region: us-east-1
- VPC ID: vpc-0032fa4e426f1dfc3
- Subnets:
  - subnet-0f3f61f029930428d
  - subnet-0172579635b5ac6ea
- Security Groups:
  - sg-0b066cd9be250c20e
  - sg-0d1faeba7e5e80eba

## Directory Structure
```
prefect-eks-setup/
├── kubernetes/
│   ├── base/
│   │   ├── namespace.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       └── prod/
│           ├── kustomization.yaml
│           ├── prefect-deployment-patch.yaml
│           └── prefect-ingressroute.yaml
└── scripts/
    ├── deploy.sh
    └── validate.sh
```

## Deployment Instructions

### 1. Validate Prerequisites
```bash
chmod +x scripts/validate.sh
./scripts/validate.sh
```
This script checks for:
- Required tools installation
- AWS credentials configuration
- EKS cluster accessibility
- VPC and networking configuration
- Traefik installation

### 2. Deploy Prefect Server
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```
The deployment script:
- Updates kubeconfig for EKS cluster access
- Creates necessary IAM service account
- Applies Kubernetes manifests using kustomize
- Verifies deployment status
- Configures Traefik IngressRoute

## Configuration Details

### Resource Requests and Limits
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### Traefik IngressRoute Configuration
- Configured for both HTTP and HTTPS (websecure)
- Path prefix: `/api`
- Strip prefix middleware enabled
- TLS enabled by default

## Troubleshooting Guide

### Common Issues

1. "Backend not found" Error
   - Verify Prefect server pod is running: `kubectl -n fp-prefect get pods`
   - Check service endpoints: `kubectl -n fp-prefect get endpoints`
   - Validate IngressRoute configuration: `kubectl -n fp-prefect get ingressroute`
   - Review Traefik logs: `kubectl -n traefik logs -l app.kubernetes.io/name=traefik`

2. IAM Permission Issues
   - Verify IAM role exists: `aws iam get-role --role-name iff_aws_nsp_admin`
   - Check service account annotation: `kubectl -n fp-prefect get serviceaccount prefect-server -o yaml`
   - Review pod events: `kubectl -n fp-prefect describe pod -l app=prefect-server`

3. Network Connectivity Issues
   - Verify VPC and subnet configuration
   - Check security group rules
   - Validate Fargate profile configuration

## Maintenance

### Updating Prefect Server
To update the Prefect server version:
1. Modify the image tag in `kubernetes/base/kustomization.yaml`
2. Rerun the deployment script

### Scaling
The deployment is configured for Fargate with appropriate resource requests/limits. To scale:
1. Modify resource values in `kubernetes/overlays/prod/prefect-deployment-patch.yaml`
2. Update the deployment: `kubectl apply -k kubernetes/overlays/prod`

## Security Considerations
- API Server endpoint is accessible both publicly and privately
- Public access source allowlist: 0.0.0.0/0
- IAM role authentication configured for Prefect server pod
- TLS enabled on Traefik IngressRoute
