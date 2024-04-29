
# ref. https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/lbc-helm.html#lbc-helm-iam
data "http" "albc_policy_json" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "albc" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.albc_policy_json.body
}

module "albc_irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.32.0"

  role_name = "alb-ingress-controller-role"

  role_policy_arns = {
    policy = aws_iam_policy.albc.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/lbc-helm.html#lbc-helm-install
# HelmはTerraformで管理せんでも良いと思うので別途。

# 適用するときは以下。こう見るとterraformからapplyしてもいいよなぁと思う。
# helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
#  -n kube-system \
#  --set clusterName=$(terraform output -raw cluster_name) \
#  --set serviceAccount.create=true \
#  --set serviceAccount.name=aws-load-balancer-controller \
#  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$(terraform output -raw irsa_iam_role_arn)" 
#