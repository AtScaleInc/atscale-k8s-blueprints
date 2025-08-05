resource "aws_efs_file_system" "eks_efs" {
  depends_on       = [module.eks]
  creation_token   = "${var.environment}-eks-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"
  tags             = var.tags
}
resource "aws_efs_mount_target" "eks_efs_mount_target" {
  for_each = { for k, v in var.private_subnets_ids : k => v }

  file_system_id  = aws_efs_file_system.eks_efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.eks_efs.id]
}


