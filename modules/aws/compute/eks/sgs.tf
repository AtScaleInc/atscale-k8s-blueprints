resource "aws_security_group" "access_sg" {
  name   = "${var.environment}-22-access"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = var.vpc_access_cidr
  }
  egress {
    from_port        = 0
    protocol         = "-1"
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "${var.environment}-22-access"
  }
}

resource "aws_security_group" "eks_efs" {
  name        = "${var.environment}-eks-efs"
  description = "Allow EFS access to EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 2049
    protocol    = "tcp"
    to_port     = 2049
    cidr_blocks = var.vpc_access_cidr
  }
}
