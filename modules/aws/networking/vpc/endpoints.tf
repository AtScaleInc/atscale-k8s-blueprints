module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.21.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [aws_security_group.endpoint_sg.id]

  endpoints = {
    s3 = {
      # interface endpoint
      service         = "s3"
      route_table_ids = module.vpc.private_route_table_ids
      tags            = { Name = "s3-vpc-endpoint" }
    },
    sts = {
      # interface endpoint
      service             = "sts"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = { Name = "sts-vpc-endpoint" }
    },
    ec2 = {
      # interface endpoint
      service             = "ec2"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = { Name = "ec2-vpc-endpoint" }
    },
    ecr = {
      # interface endpoint
      service             = "ecr.api"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = { Name = "ecr-vpc-endpoint" }
    },
    logs = {
      # interface endpoint
      service             = "logs"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = { Name = "logs-vpc-endpoint" }
    },
    ecr_dcr = {
      # interface endpoint
      service             = "ecr.dkr"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = { Name = "ecr_dcr-vpc-endpoint" }
    },
  }
}
