module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.k8s_version

  enable_cluster_creator_admin_permissions = true
  service_ipv4_cidr                        = "10.0.0.0/16"
  vpc_id                                   = var.vpc_id
  subnet_ids                               = var.private_subnets_ids
  control_plane_subnet_ids                 = var.private_subnets_ids

  endpoint_private_access = true
  endpoint_public_access  = true
  enable_irsa             = true

  addons = {
    eks-pod-identity-agent = {
      before_compute    = true
      resolve_conflicts = "OVERWRITE"
    }
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
      before_compute    = true
    }
    aws-efs-csi-driver = {
      before_compute           = true
      service_account_role_arn = "${aws_iam_role.efs_csi_driver.arn}"
      resolve_conflicts        = "OVERWRITE"
    }

    aws-ebs-csi-driver = {
      before_compute           = true
      service_account_role_arn = "${aws_iam_role.ebs_csi_driver.arn}"
      resolve_conflicts        = "OVERWRITE"
    }

    metrics-server = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  # Encryption key
  kms_key_administrators = var.sso_enabled ? [
    for user in var.aws_auth_sso_users : user.arn if user.role == "devops"
  ] : []

  access_entries = local.eks_sso_users

  eks_managed_node_groups = {
    workers = {
      vpc_security_group_ids = [aws_security_group.access_sg.id, aws_security_group.eks_efs.id]
      ami_type               = var.eks_ami_type
      instance_types         = var.eks_instance_types
      min_size               = var.eks_workers_min_instance_count
      max_size               = var.eks_workers_max_instance_count
      desired_size           = var.eks_workers_desired_instance_count
      capacity_type          = var.enable_spot_instances ? "SPOT" : "ON_DEMAND"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 120
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      update_config = {
        max_unavailable = 1
      }
      node_repair_configuration = {
        auto_repair = false
      }
    }
  }
  node_security_group_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    metrics_server_allow_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 10251
      to_port                       = 10251
      source_cluster_security_group = true
      description                   = "Allow access from control plane to metrics server webhook"
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

}

