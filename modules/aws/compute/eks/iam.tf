# Policy attachment for the worker node group to access EC2
resource "aws_iam_role_policy_attachment" "eks_ec2_access" {
  policy_arn = data.aws_iam_policy.ec2_access.arn
  role       = module.eks.eks_managed_node_groups["workers"].iam_role_name
}

# Policy attachment for the worker node group to access Load Balancer
resource "aws_iam_role_policy_attachment" "eks_lb_access" {
  policy_arn = data.aws_iam_policy.lb_access.arn
  role       = module.eks.eks_managed_node_groups["workers"].iam_role_name
}

# Policy attachment for the worker node group to access EFS
resource "aws_iam_role_policy_attachment" "eks_efs_access" {
  policy_arn = data.aws_iam_policy.efs_access.arn
  role       = module.eks.eks_managed_node_groups["workers"].iam_role_name
}

# Create IAM role for EFS CSI Driver
resource "aws_iam_role" "efs_csi_driver" {
  name = "${var.environment}-AmazonEKS_EFS_CSI_Driver"

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
            "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:sub" : "system:serviceaccount:kube-system:efs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

# Attach EFS access policy to EFS CSI Driver role
resource "aws_iam_role_policy_attachment" "efs_csi_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_driver.name
}

# Create IAM role for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.environment}-AmazonEKS_EBS_CSI_Driver"

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
            "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

# Attach EBS access policy to EBS CSI Driver role
resource "aws_iam_role_policy_attachment" "ebs_csi_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}
