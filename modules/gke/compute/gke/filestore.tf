
resource "kubectl_manifest" "filestore_sc_dynamic" {
  yaml_body = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: filestore
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: filestore.csi.storage.gke.io
parameters:
  tier: ${var.tier}
  network: ${var.network}
volumeBindingMode: Immediate
allowVolumeExpansion: true
YAML
}
