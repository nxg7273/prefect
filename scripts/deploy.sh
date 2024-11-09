#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration variables
CLUSTER_NAME="protein-engineering-cluster-new"
REGION="us-east-1"
NAMESPACE="fp-prefect"
SERVICE_ACCOUNT_NAME="prefect-server"
IAM_ROLE_NAME="iff_aws_nsp_admin"

echo -e "${YELLOW}Starting Prefect Server deployment on EKS Fargate${NC}"

# Step 1: Validate AWS credentials and cluster access
echo -e "\n${YELLOW}Step 1: Validating AWS credentials and cluster access${NC}"
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

# Step 2: Update kubeconfig for EKS cluster
echo -e "\n${YELLOW}Step 2: Updating kubeconfig for EKS cluster${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Step 3: Create IAM service account for Prefect
echo -e "\n${YELLOW}Step 3: Creating IAM service account for Prefect${NC}"
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --region=$REGION \
    --name=$SERVICE_ACCOUNT_NAME \
    --namespace=$NAMESPACE \
    --role-name=$IAM_ROLE_NAME \
    --override-existing-serviceaccounts \
    --approve

# Step 4: Apply Kubernetes manifests
echo -e "\n${YELLOW}Step 4: Applying Kubernetes manifests${NC}"
kubectl apply -k ../kubernetes/overlays/prod

# Step 5: Wait for deployment
echo -e "\n${YELLOW}Step 5: Waiting for deployment to be ready${NC}"
kubectl -n $NAMESPACE rollout status deployment/prefect-server

# Step 6: Verify Traefik IngressRoute
echo -e "\n${YELLOW}Step 6: Verifying Traefik IngressRoute${NC}"
kubectl -n $NAMESPACE get ingressroute prefect-server

# Step 7: Display deployment information
echo -e "\n${YELLOW}Step 7: Displaying deployment information${NC}"
echo -e "${GREEN}Prefect Server deployment completed successfully!${NC}"
echo -e "Namespace: $NAMESPACE"
echo -e "Service Account: $SERVICE_ACCOUNT_NAME"
kubectl -n $NAMESPACE get pods,svc,ingressroute

# Make the script executable
chmod +x deploy.sh
