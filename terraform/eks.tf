
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.name
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  # Controle Planeへのアクセスはprivateにし、基本Cloud9を踏み台にする
  cluster_endpoint_public_access = false
  # Fargate

  # Fargate profiles use the cluster primary security group so these are not utilized
  # ref. https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/fargate_profile/main.tf
  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profiles = {
    app = {
      name = "app"
      selectors = [
        {
          namespace = "backend"
        },
        {
          namespace = "frontend"
        }
      ]

      # Using specific subnets instead of the subnets supplied for the cluster itself
      subnet_ids = module.vpc.private_subnets
    }
    argocd = {
      name       = "argocd-profile"
      subnet_ids = module.vpc.private_subnets
      selectors = [
        {
          namespace = "argocd"
      }]
    }
    kube-system = {
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }

  # auth_mapは古い仕組みなので。
  authentication_mode = "API"

  access_entries = merge(var.access_entries, {
    cloud9 = {
      kubernetes_groups = []
      type              = "STANDARD"
      principal_arn     = aws_iam_role.cloud9_role.arn
      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

  })
  # ひとまず全部のログ収集しておく
  cluster_enabled_log_types = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

  cluster_addons = {

    coredns = {
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    kube-proxy = {
      most_recent = true
    }
    # IRSAよりも新しい仕組みを利用する
    eks-pod-identity-agent = {
      most_recent = true
    }
  }
  cluster_security_group_id = aws_security_group.eks_security_group.id
}

resource "aws_security_group" "eks_security_group" {
  name   = "bastion_cloud9_sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [data.aws_security_group.cloud9_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
