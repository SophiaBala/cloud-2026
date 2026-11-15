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

variable "alert_email" {
  type        = string
  default     = null
  description = "Email for CloudWatch alarms; defaults to budget_email"
}

variable "autoscaling_min" {
  type    = number
  default = 1
}

variable "autoscaling_max" {
  type    = number
  default = 4
  validation {
    condition     = var.autoscaling_max <= 4
    error_message = "Lab limit: no more than 4 tasks."
  }
}

variable "cpu_target" {
  type    = number
  default = 60
}

variable "cache_enabled" {
  type    = bool
  default = true
}

variable "cache_ttl_seconds" {
  type    = number
  default = 45
}
