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

variable "app_dir" {
  type    = string
  default = "./database-ir-2025-lab4"
}