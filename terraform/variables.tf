
variable "region" {
  type        = string
  default     = "ap-northeast-1"
}
variable "access_entries" {
  type = map
  description = "ref. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry"
}
variable "cloud9_access_users" {
  description = "IAM user arns who wants to access cloud9 IDE"
  type = list(string)
}