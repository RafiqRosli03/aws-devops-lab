variable "cluster_name" {
  type = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider."
  type        = string
}

variable "oidc_provider" {
  description = "OIDC provider URL without the https:// prefix (e.g. oidc.eks.<region>.amazonaws.com/id/XXXX)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
