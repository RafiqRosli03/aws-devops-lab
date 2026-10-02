variable "name" {
  type = string
}

variable "secret_names" {
  type    = list(string)
  default = ["orders-node", "users-python"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
