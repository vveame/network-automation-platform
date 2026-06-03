data "aws_ssm_parameter" "al2023_ami" {
  count = var.enable_compute ? 1 : 0
  name  = var.ami_ssm_parameter
}

locals {
  create_key_pair = var.enable_compute && var.admin_public_key != null && trimspace(var.admin_public_key) != ""
  ssh_key_name    = local.create_key_pair ? aws_key_pair.admin[0].key_name : null
}

resource "aws_key_pair" "admin" {
  count = local.create_key_pair ? 1 : 0

  key_name   = "${var.name_prefix}-admin-key"
  public_key = var.admin_public_key

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-admin-key"
    Role = "ec2-admin-access"
  })
}

resource "aws_instance" "bastion" {
  count = var.enable_compute ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.admin_security_group_id]
  associate_public_ip_address = true
  key_name                    = local.ssh_key_name

  user_data = <<-EOF_USER_DATA
    #!/bin/bash
    hostnamectl set-hostname ${var.name_prefix}-bastion
    cat > /etc/motd <<'MOTD'
    PFE Cloud Bastion / Admin Node
    Managed by Terraform.
    MOTD
  EOF_USER_DATA

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-bastion"
    Role = "bastion-admin"
    Tier = "public"
  })
}

resource "aws_instance" "monitoring" {
  count = var.enable_compute ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type               = var.instance_type
  subnet_id                   = var.monitoring_subnet_id
  vpc_security_group_ids      = [var.monitoring_security_group_id]
  associate_public_ip_address = false
  key_name                    = local.ssh_key_name

  user_data = <<-EOF_USER_DATA
    #!/bin/bash
    hostnamectl set-hostname ${var.name_prefix}-monitoring
    cat > /etc/motd <<'MOTD'
    PFE Cloud Monitoring Placeholder
    Future role: Prometheus / Grafana / telemetry ingestion.
    Managed by Terraform.
    MOTD
  EOF_USER_DATA

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-monitoring"
    Role = "monitoring"
    Tier = "monitoring-ai"
  })
}

resource "aws_instance" "ai" {
  count = var.enable_compute ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type               = var.instance_type
  subnet_id                   = var.monitoring_subnet_id
  vpc_security_group_ids      = [var.ai_security_group_id]
  associate_public_ip_address = false
  key_name                    = local.ssh_key_name

  user_data = <<-EOF_USER_DATA
    #!/bin/bash
    hostnamectl set-hostname ${var.name_prefix}-ai
    cat > /etc/motd <<'MOTD'
    PFE Cloud AI Analysis Placeholder
    Future role: anomaly detection / decision support service.
    Managed by Terraform.
    MOTD
  EOF_USER_DATA

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ai"
    Role = "ai-analysis"
    Tier = "monitoring-ai"
  })
}
