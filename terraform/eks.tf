data "aws_iam_user" "terraform_user" {
  user_name = "terraform"
}
data "aws_iam_role" "admins" {
  name = "AWSReservedSSO_AdministratorAccess_cf5310046a6d383d"
}
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.name
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  # 手元からControl Planeにアクセスしたいので。
  cluster_endpoint_public_access = true
  # EC2のインスタンスをData PlaneのNodeに使用する
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    desired_size   = 1
    instance_types = ["t3.small"]
  }
  eks_managed_node_groups = {
    one = {
      name           = "node-group-1"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }

    two = {
      name           = "node-group-2"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }
  # auth_mapは古い仕組みなので。
  authentication_mode = "API"
  # 取り急ぎterraformで使っているユーザーは管理者権限でアクセスできるようにしておく
  access_entries = var.access_entries
  # ひとまず全部のログ収集しておく
  cluster_enabled_log_types = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    # IRSAよりも新しい仕組みを利用する
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

}
