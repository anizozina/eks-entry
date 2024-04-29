
variable "region" {
  type        = string
  default     = "ap-northeast-1"
}
variable "access_entries" {
  type = map
  description = "ref. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry"
}