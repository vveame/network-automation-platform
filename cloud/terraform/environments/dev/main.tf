# Cloud baseline entry point.
#
# Modules will be added progressively:
# - network: VPC, subnets, route tables, internet gateway
# - security: security groups and access rules
# - storage: S3 bucket for logs, metrics exports and analysis outputs
# - compute: EC2 instances for monitoring and AI components

# module "network" {
#   source = "../../modules/network"
# }