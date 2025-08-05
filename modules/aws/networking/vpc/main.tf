module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name            = "${var.environment}-vpc"
  cidr            = var.vpc_cidr
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway                 = true
  map_public_ip_on_launch            = false
  propagate_private_route_tables_vgw = false
  enable_dns_hostnames               = true
  enable_flow_log                    = false

  public_subnet_tags = {
    "Tier"                                      = "Public"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = 1
  }

  private_subnet_tags = {
    "Tier"                                      = "Private"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = 1
  }

}



