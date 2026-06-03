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

  name_prefix                       = local.name_prefix
  bucket_name_override              = var.storage_bucket_name_override
  validation_artifact_retention_days = var.validation_artifact_retention_days
  noncurrent_version_retention_days  = var.noncurrent_version_retention_days
  common_tags                       = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  enable_compute               = var.enable_compute
  name_prefix                  = local.name_prefix
  ami_ssm_parameter            = var.compute_ami_ssm_parameter
  instance_type                = var.compute_instance_type
  admin_public_key             = var.admin_public_key
  public_subnet_id             = module.network.public_subnet_id
  monitoring_subnet_id         = module.network.monitoring_subnet_id
  admin_security_group_id      = module.security.admin_security_group_id
  monitoring_security_group_id = module.security.monitoring_security_group_id
  ai_security_group_id         = module.security.ai_security_group_id
  common_tags                  = local.common_tags
}

module "vpn" {
  source = "../../modules/vpn"

  enable_vpn                = var.enable_vpn
  name_prefix               = local.name_prefix
  vpc_id                    = module.network.vpc_id
  public_route_table_id     = module.network.public_route_table_id
  private_route_table_id    = module.network.private_route_table_id
  monitoring_route_table_id = module.network.monitoring_route_table_id
  onprem_public_ip          = var.onprem_public_ip
  onprem_cidr_blocks        = var.onprem_cidr_blocks
  onprem_bgp_asn            = var.onprem_bgp_asn
  aws_bgp_asn               = var.aws_bgp_asn
  common_tags               = local.common_tags
}
