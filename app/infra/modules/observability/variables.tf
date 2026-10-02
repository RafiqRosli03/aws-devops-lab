variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications (via SNS). Requires confirming the subscription email."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ingress ALB (e.g. app/k8s-dev-apps-xxxx/yyyy) for CloudWatch ALB metrics. The ALB is created by the Ingress controller, so this is passed in."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
