#
# Create random password for BIG-IQ
#
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}
#
# Create Secret Store and Store BIG-IP Password
#
resource "aws_secretsmanager_secret" "bigiq" {
  name = format("%s-bigiq-secret-%s", var.prefix, var.random.hex)
}
resource "aws_secretsmanager_secret_version" "bigiq-pwd" {
  secret_id     = aws_secretsmanager_secret.bigiq.id
  secret_string = random_password.password.result
}
#
# Create the BIG-IP appliances
#
module "bigip" {
  # source  = "f5devcentral/bigip/aws"
  # version = "0.1.2"
  source = "github.com/f5devcentral/terraform-aws-bigip?ref=ip-outputs"

  prefix = format(
    "%s-bigiq-2-nic_with_new_vpc-%s",
    var.prefix,
    var.random.hex
  )
  aws_secretmanager_secret_id = aws_secretsmanager_secret.bigiq.id
  f5_ami_search_name          = "F5 Networks BYOL BIG-IQ-7.0.0.1.0.0.6*"
  f5_instance_count           = length(var.azs)
  ec2_key_name                = var.keyname
  ec2_instance_type           = "c4.xlarge"
  # DO_URL                      = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.9.0/f5-declarative-onboarding-1.9.0-1.noarch.rpm"

  mgmt_subnet_security_group_ids = [
    module.bigip_sg.this_security_group_id,
    module.bigip_mgmt_sg.this_security_group_id
  ]

  private_subnet_security_group_ids = [
    module.bigip_sg.this_security_group_id,
    module.bigip_mgmt_sg.this_security_group_id
  ]

  vpc_private_subnet_ids = var.private_subnets
  vpc_mgmt_subnet_ids    = var.database_subnets
}
#
# Create a security group for BIG-IP
#
module "bigip_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = format("%s-bigip-%s", var.prefix, var.random.hex)
  description = "Security group for BIG-IQ Demo"
  vpc_id      = var.vpcid

  ingress_cidr_blocks = [var.allowed_app_cidr]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]

  ingress_with_source_security_group_id = [
    {
      rule                     = "all-all"
      source_security_group_id = module.bigip_sg.this_security_group_id
    }
  ]

  # Allow ec2 instances outbound Internet connectivity
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]
}
#
# Create a security group for BIG-IQ Management
#
module "bigip_mgmt_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = format("%s-bigip-mgmt-%s", var.prefix, var.random.hex)
  description = "Security group for BIG-IQ Demo"
  vpc_id      = var.vpcid

  ingress_cidr_blocks = [var.allowed_mgmt_cidr]
  ingress_rules       = ["https-443-tcp", "https-8443-tcp", "ssh-tcp"]

  ingress_with_source_security_group_id = [
    {
      rule                     = "all-all"
      source_security_group_id = module.bigip_mgmt_sg.this_security_group_id
    }
  ]

  # Allow ec2 instances outbound Internet connectivity
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]
}