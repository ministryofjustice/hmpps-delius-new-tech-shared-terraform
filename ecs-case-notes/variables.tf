# region
variable "region" {}

variable "remote_state_bucket_name" {
  description = "Terraform remote state bucket name"
}

variable "cloudwatch_log_retention" {}

variable "case-notes-image_url" {
  default = "mongo:latest"
}

variable "mongodb_root_user" {
  default = "root"
}

# LB
variable "cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing"
  default     = true
}

variable "idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle"
  default     = 60
}

variable "connection_draining" {
  description = "Boolean to enable connection draining"
  default     = false
}

variable "connection_draining_timeout" {
  description = "The time in seconds to allow for connections to drain"
  default     = 300
}

variable "case-notes-listener" {
  description = "A list of listener blocks"
  type        = "list"
}

variable "access_logs" {
  description = "An access logs block"
  type        = "list"
  default     = []
}

variable "case-notes-health_check" {
  description = "A health check block"
  type        = "list"
}

# ECS service
variable "case-notes-service_desired_count" {
  default = 1
}

variable "push_base_url" {
  default = "http://localhost:8085/delius"
}
