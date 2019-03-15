# region
variable "region" {}

variable "remote_state_bucket_name" {
  description = "Terraform remote state bucket name"
}

variable "cloudwatch_log_retention" {}

variable "image_url" {
  default = "case-notes:latest"
}

variable "mongodb_root_user" {
  default = "root"
}
