module "network" {
  source = "../../modules/network"

  name_prefix            = local.name_prefix
  vpc_cidr               = var.vpc_cidr
  public_subnet_cidr     = var.public_subnet_cidr
  private_subnet_cidr    = var.private_subnet_cidr
  monitoring_subnet_cidr = var.monitoring_subnet_cidr
  availability_zone      = var.availability_zone
  common_tags            = local.common_tags
}
