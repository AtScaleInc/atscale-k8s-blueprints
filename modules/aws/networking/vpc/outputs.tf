
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}

output "private_subnets_ids" {
  value = module.vpc.private_subnets
}

output "public_subnets_ids" {
  value = module.vpc.public_subnets
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr_block
}
