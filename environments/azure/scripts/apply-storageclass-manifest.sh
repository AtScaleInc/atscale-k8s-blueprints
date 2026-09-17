#!/bin/bash
#
# Apply the azurefile-csi-nfs StorageClass, giving the cluster a ReadWriteMany
# (RWX) storage option backed by Azure Files over NFS.
#
# This is a day-2, in-cluster step and lives outside Terraform on purpose, for
# the same reason as apply-alb-manifest.sh: AKS with Azure AD RBAC needs
# kubelogin exec-auth, which the Terraform kubernetes/kubectl providers don't
# handle cleanly. Running it here, after credentials are fetched, avoids that
# provider bootstrap entirely.
#
# NFS (not the default SMB-backed azurefile-csi class) is required because
# AtScale performs POSIX file operations (e.g. file locking, permission bits)
# against the RWX volume that SMB does not support.
#
# Usage: apply-storageclass-manifest.sh [storage_class_name]

set -euo pipefail

STORAGE_CLASS_NAME="${1:-azurefile-csi-nfs}"

echo "Applying StorageClass '${STORAGE_CLASS_NAME}' (Azure Files, NFS protocol)..."
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STORAGE_CLASS_NAME}
provisioner: file.csi.azure.com
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  protocol: nfs
mountOptions:
  - nconnect=4
EOF

echo "StorageClass '${STORAGE_CLASS_NAME}' is ready."
