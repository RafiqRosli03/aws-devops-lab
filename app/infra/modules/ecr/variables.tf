variable "repository_names" {
  type        = list(string)
  description = "ECR repository names, one per app."
}

variable "tags" {
  type    = map(string)
  default = {}
}
