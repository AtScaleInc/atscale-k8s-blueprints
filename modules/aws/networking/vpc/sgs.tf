resource "aws_security_group" "endpoint_sg" {
  name   = "${var.environment}-endpoint-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port        = 0
    protocol         = "-1"
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "${var.environment}-endpoint-sg"
  }
}
