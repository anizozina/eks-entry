# VPCの要件について
# ref. https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/network_reqs.html

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = local.name

  cidr = "172.16.0.0/16"
  azs  = local.azs

  public_subnets = ["172.16.16.0/20", "172.16.32.0/20", "172.16.48.0/20"]
  private_subnets = [
    # for application subnet
    "172.16.64.0/20", "172.16.80.0/20", "172.16.96.0/20"
  ]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    # automatically added by eks. specify to prevent diffs
    "kubernetes.io/cluster/${local.name}" = "shared"
    # need to deploy load balancer to subnet.
    # without it, public subet try to get router using IGW
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }
  # For RDS 
  # database_subnets = [
  #   "172.16.112.0/24", "172.16.128.0/24", "172.16.144.0/24"
  # ]
  create_database_subnet_group = true
  tags                         = local.tags
}
