# ref. https://docs.aws.amazon.com/ja_jp/cloud9/latest/user-guide/ec2-ssm.html#aws-cli-instance-profiles

data "aws_iam_policy_document" "cloud9_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com","cloud9.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloud9_role" {
  name               = "AWSCloud9SSMAccessRole"
  path               = "/service-role/"
  assume_role_policy = data.aws_iam_policy_document.cloud9_assume_role.json
}
data "aws_iam_policy" "ssm_instance_profile" {
  arn = "arn:aws:iam::aws:policy/AWSCloud9SSMInstanceProfile"
}
resource "aws_iam_role_policy_attachment" "cloud9_attach_role" {
  role       = aws_iam_role.cloud9_role.name
  policy_arn = data.aws_iam_policy.ssm_instance_profile.arn
}


resource "aws_iam_instance_profile" "cloud9_instance_profile" {
  name = "AWSCloud9SSMInstanceProfile"
  role = aws_iam_role.cloud9_role.name
  path = "/cloud9/"
}

data "aws_iam_policy" "admin_policy" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "cloud9_attach_admin_role" {
  role       = aws_iam_role.cloud9_role.name
  policy_arn = data.aws_iam_policy.admin_policy.arn
}

resource "aws_cloud9_environment_ec2" "bastion" {
  name          = "bastion_server"
  description   = "bastion server for eks private access"
  instance_type = "t2.micro"
  image_id      = "amazonlinux-2023-x86_64"
  subnet_id     = module.vpc.public_subnets[1]
  connection_type = "CONNECT_SSM"
}

resource "aws_cloud9_environment_membership" "cloud9_user" {
  for_each = toset(var.cloud9_access_users)

  environment_id = aws_cloud9_environment_ec2.bastion.id
  permissions    = "read-write"

  user_arn       = each.key
}

data "aws_instance" "cloud9_instance" {
  filter {
    name = "tag:aws:cloud9:environment"
    values = [
    aws_cloud9_environment_ec2.bastion.id]
  }
}
data "aws_security_group" "cloud9_sg" {
    filter {
    name = "tag:aws:cloud9:environment"
        values = [
          aws_cloud9_environment_ec2.bastion.id
        ]
    }
}