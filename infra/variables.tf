variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "myapp"
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "image_tag" {
  type    = string
  default = "initial"
}

variable "github_repo" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "budget_email" {
  type        = string
  description = "Email for budget alerts"
}

variable "budget_limit_usd" {
  type    = string
  default = "10"
}
