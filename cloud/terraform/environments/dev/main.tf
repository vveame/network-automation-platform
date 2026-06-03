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

module "security" {
  source = "../../modules/security"

  name_prefix        = local.name_prefix
  vpc_id             = module.network.vpc_id
  vpc_cidr           = module.network.vpc_cidr
  admin_allowed_cidr = var.admin_allowed_cidr
  common_tags        = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  name_prefix          = local.name_prefix
  bucket_name_override = var.storage_bucket_name_override
  common_tags          = local.common_tags
}
