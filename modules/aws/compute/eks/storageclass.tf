terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

## Kubernetes StorageClass for EFS
resource "kubectl_manifest" "efs_sc" {
  provider   = kubectl
  depends_on = [module.eks]
  yaml_body  = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  volumeBindingMode: Immediate
  provisioningMode: efs-ap
  fileSystemId: ${aws_efs_file_system.eks_efs.id}
  directoryPerms: "755"
allowVolumeExpansion: true
reclaimPolicy: Delete
YAML
}

resource "kubectl_manifest" "default" {
  provider   = kubectl
  depends_on = [module.eks]
  yaml_body  = <<YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: default
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
    provisioner: ebs.csi.aws.com
    parameters:
      type: gp2
    volumeBindingMode: Immediate
    reclaimPolicy: Delete
    allowVolumeExpansion: true
YAML
}
