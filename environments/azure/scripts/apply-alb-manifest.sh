#!/bin/bash
#
# Bootstrap a default ApplicationLoadBalancer resource so an Application Gateway
# for Containers is provisioned for the cluster out of the box.
#
# This is a day-2, in-cluster step and lives outside Terraform on purpose: the
# ApplicationLoadBalancer is a Kubernetes custom resource whose CRD is installed
# by the ALB controller add-on only after the cluster is up. Running it here,
# after credentials are fetched, avoids the Terraform kubernetes-provider
# bootstrap and CRD-timing problems.
#
# Usage: apply-alb-manifest.sh <alb_subnet_id> [namespace] [alb_name]

set -euo pipefail

SUBNET_ID="${1:?alb_subnet_id is required}"
NAMESPACE="${2:-alb-infra}"
ALB_NAME="${3:-default-alb}"

CRD="applicationloadbalancer.alb.networking.azure.io"

echo "Waiting for the ApplicationLoadBalancer CRD to be registered by the ALB controller add-on..."
CRD_READY=false
for _ in $(seq 1 40); do
  if kubectl get crd "$CRD" >/dev/null 2>&1; then
    CRD_READY=true
    break
  fi
  sleep 15
done

if [ "$CRD_READY" != "true" ]; then
  echo "ERROR: CRD '$CRD' did not appear after ~10 minutes."
  echo "       The ALB controller add-on may not be enabled, or is still starting."
  echo "       Check: kubectl get pods -n kube-system | grep alb-controller"
  exit 1
fi

echo "Applying ApplicationLoadBalancer '$ALB_NAME' in namespace '$NAMESPACE'..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
---
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: ${ALB_NAME}
  namespace: ${NAMESPACE}
spec:
  associations:
  - ${SUBNET_ID}
EOF

echo "Waiting for the Application Gateway for Containers to provision (typically 5-6 minutes)..."
DEPLOYED=false
for _ in $(seq 1 40); do
  REASON=$(kubectl get applicationloadbalancer "$ALB_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.status.conditions[?(@.type=="Deployment")].reason}' 2>/dev/null || true)
  if [ "$REASON" = "Ready" ]; then
    DEPLOYED=true
    break
  fi
  sleep 15
done

echo ""
if [ "$DEPLOYED" = "true" ]; then
  ALB_ID=$(kubectl get applicationloadbalancer "$ALB_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.status.conditions[?(@.type=="Deployment")].message}' 2>/dev/null | sed 's/^alb-id=//')
  echo "Application Gateway for Containers is ready."
  echo "  alb-id: ${ALB_ID}"
  echo ""
  echo "Reference it from a Gateway or Ingress. For an Ingress, set:"
  echo "  alb.networking.azure.io/alb-id: ${ALB_ID}"
else
  echo "The ApplicationLoadBalancer was applied but is not Ready yet."
  echo "It usually finishes within a few more minutes. Check with:"
  echo "  kubectl get applicationloadbalancer ${ALB_NAME} -n ${NAMESPACE} -o yaml"
fi
