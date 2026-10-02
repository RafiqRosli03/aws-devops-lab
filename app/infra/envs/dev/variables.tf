variable "region" {
  type    = string
  default = "ap-southeast-5"
}

variable "account_id" {
  type    = string
  default = "497862079645"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "node_min" {
  type    = number
  default = 2
}

variable "node_max" {
  type    = number
  default = 4
}

variable "node_desired" {
  type    = number
  default = 2
}

variable "gitlab_url" {
  type    = string
  default = "https://gitlab.com"
}

variable "gitlab_project_path" {
  type        = string
  description = "Your GitLab group/project path, e.g. my-group/devops-lab. Set in dev.tfvars."
  default     = "CHANGE-ME/devops-lab"
}

variable "alert_email" {
  type        = string
  description = "Email for CloudWatch alarm notifications (Phase 5). Set in dev.tfvars."
  default     = ""
}

variable "alb_arn_suffix" {
  type        = string
  description = "Ingress ALB ARN suffix for CloudWatch metrics (Phase 5). The ALB is created by the Ingress controller; set after it exists."
  default     = ""
}
