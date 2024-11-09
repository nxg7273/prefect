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
POLICY_NAME="PrefectEKSFargatePolicy"

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

# Step 3: Create IAM policy for Prefect if it doesn't exist
echo -e "\n${YELLOW}Step 3: Creating IAM policy for Prefect${NC}"
POLICY_ARN=""
if aws iam get-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME 2>/dev/null; then
    echo "Policy $POLICY_NAME already exists"
    POLICY_ARN=$(aws iam get-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME --query Policy.Arn --output text)
else
    echo "Creating new policy $POLICY_NAME"
    POLICY_ARN=$(aws iam create-policy \
        --policy-name $POLICY_NAME \
        --policy-document file://iam/policies/prefect-policy.json \
        --query Policy.Arn --output text)
fi

# Step 4: Attach policy to IAM role if not already attached
echo -e "\n${YELLOW}Step 4: Attaching policy to IAM role${NC}"
if ! aws iam list-attached-role-policies --role-name $IAM_ROLE_NAME | grep -q $POLICY_ARN; then
    aws iam attach-role-policy \
        --role-name $IAM_ROLE_NAME \
        --policy-arn $POLICY_ARN
    echo "Policy attached to role $IAM_ROLE_NAME"
else
    echo "Policy already attached to role $IAM_ROLE_NAME"
fi

# Step 5: Create IAM service account for Prefect
echo -e "\n${YELLOW}Step 5: Creating IAM service account for Prefect${NC}"
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --region=$REGION \
    --name=$SERVICE_ACCOUNT_NAME \
    --namespace=$NAMESPACE \
    --role-name=$IAM_ROLE_NAME \
    --override-existing-serviceaccounts \
    --approve

# Step 6: Apply Kubernetes manifests
echo -e "\n${YELLOW}Step 6: Applying Kubernetes manifests${NC}"
kubectl apply -k ../kubernetes/overlays/prod

# Step 7: Wait for deployment
echo -e "\n${YELLOW}Step 7: Waiting for deployment to be ready${NC}"
kubectl -n $NAMESPACE rollout status deployment/prefect-server

# Step 8: Verify Traefik IngressRoute
echo -e "\n${YELLOW}Step 8: Verifying Traefik IngressRoute${NC}"
kubectl -n $NAMESPACE get ingressroute prefect-server

# Step 9: Display deployment information
echo -e "\n${YELLOW}Step 9: Displaying deployment information${NC}"
echo -e "${GREEN}Prefect Server deployment completed successfully!${NC}"
echo -e "Namespace: $NAMESPACE"
echo -e "Service Account: $SERVICE_ACCOUNT_NAME"
echo -e "IAM Role: $IAM_ROLE_NAME"
echo -e "IAM Policy: $POLICY_NAME"
kubectl -n $NAMESPACE get pods,svc,ingressroute

# Make the script executable
chmod +x deploy.sh
