#!/bin/bash

set -euo pipefail

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

aws eks update-kubeconfig --region $AWS_REGION --name ontra-eks-cluster --alias ontra

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

eksctl utils associate-iam-oidc-provider \
  --region=$AWS_REGION \
  --cluster=ontra-eks-cluster \
  --approve

eksctl create iamserviceaccount \
  --cluster=ontra-eks-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

helm repo add eks https://aws.github.io/eks-charts

helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=ontra-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --namespace kube-system