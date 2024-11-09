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
VPC_ID="vpc-0032fa4e426f1dfc3"
SUBNETS=("subnet-0f3f61f029930428d" "subnet-0172579635b5ac6ea")
SECURITY_GROUPS=("sg-0b066cd9be250c20e" "sg-0d1faeba7e5e80eba")

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ $1 is installed${NC}"
    return 0
}

check_aws_resource() {
    local resource_type=$1
    local resource_id=$2
    local command=$3

    echo -n "Checking $resource_type ($resource_id)... "
    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}Failed${NC}"
        return 1
    fi
}

echo -e "${YELLOW}Starting Prefect Server Prerequisites Validation${NC}"

# Step 1: Check required tools
echo -e "\n${YELLOW}Step 1: Checking required tools${NC}"
check_command "aws" || exit 1
check_command "kubectl" || exit 1
check_command "eksctl" || exit 1

# Step 2: Check AWS credentials
echo -e "\n${YELLOW}Step 2: Checking AWS credentials${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials configured${NC}"

# Step 3: Check EKS cluster
echo -e "\n${YELLOW}Step 3: Checking EKS cluster${NC}"
check_aws_resource "EKS Cluster" "$CLUSTER_NAME" \
    "aws eks describe-cluster --name $CLUSTER_NAME --region $REGION" || exit 1

# Step 4: Check VPC and networking
echo -e "\n${YELLOW}Step 4: Checking VPC and networking${NC}"
check_aws_resource "VPC" "$VPC_ID" \
    "aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $REGION" || exit 1

for subnet in "${SUBNETS[@]}"; do
    check_aws_resource "Subnet" "$subnet" \
        "aws ec2 describe-subnets --subnet-ids $subnet --region $REGION" || exit 1
done

for sg in "${SECURITY_GROUPS[@]}"; do
    check_aws_resource "Security Group" "$sg" \
        "aws ec2 describe-security-groups --group-ids $sg --region $REGION" || exit 1
done

# Step 5: Check Kubernetes connectivity
echo -e "\n${YELLOW}Step 5: Checking Kubernetes connectivity${NC}"
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes connectivity verified${NC}"

# Step 6: Check Traefik installation
echo -e "\n${YELLOW}Step 6: Checking Traefik installation${NC}"
if ! kubectl get crd ingressroutes.traefik.containo.us &> /dev/null; then
    echo -e "${RED}Error: Traefik CRDs not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Traefik installation verified${NC}"

echo -e "\n${GREEN}All prerequisites validated successfully!${NC}"
