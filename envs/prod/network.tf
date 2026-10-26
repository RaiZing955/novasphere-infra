# Le VPC vient du module public du registre (on ne reecrit pas une brique standard).
# Pas de NAT Gateway : les instances sont en subnets publics, protegees par leurs Security Groups.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [cidrsubnet(local.vpc_cidr, 8, 1), cidrsubnet(local.vpc_cidr, 8, 2)]
  private_subnets = []

  enable_nat_gateway      = false
  map_public_ip_on_launch = true # sans IP publique, pas de sortie Internet donc pas d'installation de nginx
  enable_dns_hostnames    = true
}
