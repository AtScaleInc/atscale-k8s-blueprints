resource "aws_iam_policy" "aws_lb_controller" {
  name   = "${var.environment}-AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/files/lb-controller-iam-policy.json")
}

resource "aws_iam_role" "aws_lb_controller" {
  name = "${var.environment}-AmazonEKS_LB_Controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        },
        Condition = {
          StringEquals = {
            "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:aud" : "sts.amazonaws.com",
            "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller" {
  policy_arn = aws_iam_policy.aws_lb_controller.arn
  role       = aws_iam_role.aws_lb_controller.name
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  # 1.14.0 (app v2.13.4) has HTTPRoute/TCPRoute support in name only: its
  # Gateway API watches are hardcoded to the old gateway.networking.k8s.io/
  # v1alpha2 TCPRoute/UDPRoute/TLSRoute, so installing the real (v1,
  # Standard-channel) CRDs makes its whole manager crash-loop, not just the
  # NLB path (confirmed on a real deploy: "no matches for kind TCPRoute in
  # version v1alpha2", then "leader election lost"). The project also
  # renumbered its releases (module sigs.k8s.io/aws-load-balancer-controller/v3,
  # chart version == app version) around the same time. v3.2.0 is the first
  # release with the actual fix (PR #4602: discovery-based Gateway API CRD
  # detection replacing the hardcoded v1alpha2 watches) — the 1.15.x/1.16.x
  # chart line never got it.
  version = "3.5.0"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "controllerConfig.featureGates.ALBGatewayAPI"
    value = var.enable_gateway_api
  }

  set {
    name  = "controllerConfig.featureGates.NLBGatewayAPI"
    value = var.enable_gateway_api
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_lb_controller.arn
  }

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.aws_lb_controller,
  ]
}

# Hash obtained with (re-run against a new URL if the pinned tag above ever
# changes, and update the hash below to match):
#   curl -sL "<url>" | shasum -a 256
data "http" "gateway_api_crds" {
  count = var.enable_gateway_api ? 1 : 0
  url   = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml"

  lifecycle {
    postcondition {
      condition     = sha256(self.response_body) == "a557172e8348f758479e9ee4000bbbb4b4aa48302a6b73461823ea5349bad56d"
      error_message = "standard-install.yaml content changed since it was pinned — verify before proceeding."
    }
  }
}

data "kubectl_file_documents" "gateway_api_crds" {
  count   = var.enable_gateway_api ? 1 : 0
  content = data.http.gateway_api_crds[0].response_body
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each   = var.enable_gateway_api ? data.kubectl_file_documents.gateway_api_crds[0].manifests : {}
  provider   = kubectl
  yaml_body  = each.value
  depends_on = [module.eks]
}

# Pinned to the same v3.5.0 tag as the controller itself (see
# helm_release.aws_lb_controller above) — the v2.13.4 file this used to
# point at only serves gateway.k8s.aws/v1beta1, but a v3.5.0 controller's
# LoadBalancerConfiguration/TargetGroupConfiguration watches look for
# gateway.k8s.aws/v1 (confirmed on a real deploy: installing the older
# CRDs crash-loops the whole manager the same way the TCPRoute/v1alpha2
# mismatch did before the controller version bump). The v3.5.0 file
# serves both v1 and v1beta1, so it's compatible either way.
# Hash obtained with (re-run against a new URL if the pinned tag above ever
# changes, and update the hash below to match):
#   curl -sL "<url>" | shasum -a 256
data "http" "aws_gateway_api_crds" {
  count = var.enable_gateway_api ? 1 : 0
  url   = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.5.0/helm/aws-load-balancer-controller/crds/gateway-crds.yaml"

  lifecycle {
    postcondition {
      condition     = sha256(self.response_body) == "fce68bbfc74b4ed7dbea675f46981cbef1fffc8981cf19c0c1e7a2e9d6464862"
      error_message = "gateway-crds.yaml content changed since it was pinned — verify before proceeding."
    }
  }
}

data "kubectl_file_documents" "aws_gateway_api_crds" {
  count   = var.enable_gateway_api ? 1 : 0
  content = data.http.aws_gateway_api_crds[0].response_body
}

resource "kubectl_manifest" "aws_gateway_api_crds" {
  for_each   = var.enable_gateway_api ? data.kubectl_file_documents.aws_gateway_api_crds[0].manifests : {}
  provider   = kubectl
  yaml_body  = each.value
  depends_on = [module.eks]
}

resource "kubectl_manifest" "alb_lb_config" {
  count      = var.enable_gateway_api ? 1 : 0
  provider   = kubectl
  depends_on = [kubectl_manifest.gateway_api_crds, kubectl_manifest.aws_gateway_api_crds]
  yaml_body  = <<YAML
apiVersion: gateway.k8s.aws/v1beta1
kind: LoadBalancerConfiguration
metadata:
  name: eks-alb-config
  namespace: kube-system
spec:
  scheme: ${var.gateway_scheme}
YAML
}

resource "kubectl_manifest" "alb_gatewayclass" {
  count    = var.enable_gateway_api ? 1 : 0
  provider = kubectl
  depends_on = [
    helm_release.aws_lb_controller,
    kubectl_manifest.gateway_api_crds,
    kubectl_manifest.aws_gateway_api_crds,
    kubectl_manifest.alb_lb_config,
  ]
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eks-alb
spec:
  controllerName: gateway.k8s.aws/alb
  parametersRef:
    group: gateway.k8s.aws
    kind: LoadBalancerConfiguration
    name: eks-alb-config
    namespace: kube-system
YAML
}

# NLB side of the same enable_gateway_api toggle — TCPRoute needs a
# separate GatewayClass from HTTPRoute's (the controller never lets one
# Gateway mix L4 and L7 listeners), but it's the same controller, the same
# CRDs, and the same feature flag turning both capabilities on at once. No
# real AWS resource (NLB) gets created here — that only happens once some
# Gateway actually uses this GatewayClass.
resource "kubectl_manifest" "nlb_lb_config" {
  count      = var.enable_gateway_api ? 1 : 0
  provider   = kubectl
  depends_on = [kubectl_manifest.gateway_api_crds, kubectl_manifest.aws_gateway_api_crds]
  yaml_body  = <<YAML
apiVersion: gateway.k8s.aws/v1beta1
kind: LoadBalancerConfiguration
metadata:
  name: eks-nlb-config
  namespace: kube-system
spec:
  scheme: ${var.gateway_scheme}
YAML
}

resource "kubectl_manifest" "nlb_gatewayclass" {
  count    = var.enable_gateway_api ? 1 : 0
  provider = kubectl
  depends_on = [
    helm_release.aws_lb_controller,
    kubectl_manifest.gateway_api_crds,
    kubectl_manifest.aws_gateway_api_crds,
    kubectl_manifest.nlb_lb_config,
  ]
  yaml_body = <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eks-nlb
spec:
  controllerName: gateway.k8s.aws/nlb
  parametersRef:
    group: gateway.k8s.aws
    kind: LoadBalancerConfiguration
    name: eks-nlb-config
    namespace: kube-system
YAML
}
