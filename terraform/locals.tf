
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name = "eks-investigation"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Name       = local.name
  }
}
