data "aws_caller_identity" "current" {}

data "aws_iam_policy" "ec2_access" {
  name = "AmazonEC2FullAccess"
}

data "aws_iam_policy" "lb_access" {
  name = "ElasticLoadBalancingFullAccess"
}

data "aws_iam_policy" "efs_access" {
  name = "AmazonElasticFileSystemClientFullAccess"
}

