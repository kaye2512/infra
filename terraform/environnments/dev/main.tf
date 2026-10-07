module "network" {
  source  = "../../modules/networks"
  vpc_cidr_block = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "security" {
  source = "../../modules/security"
  environment = var.environment
  ssh_allowed_cidr = var.ssh_allowed_cidr
  vpc_id = module.network.main_vpc_id
}

module "compute" {
    source = "../../modules/compute"
    ami_id = var.ami_id
    instance_type = var.instance_type
    environment = var.environment
    subnet_id = module.network.public_subnet_id
    security_group_id = module.security.public_sg_id
    instance_name = "${var.environment}-ec2-instance"
    hostname = var.hostname
    username = var.username
    ssh_public_key = var.ssh_public_key
}
