variable "region" {}

variable "remote_state_bucket_name" {
  description = "Terraform remote state bucket name"
}

variable depends_on {
  default = []
  type    = "list"
}

variable "user_access_cidr_blocks" {
  type = "list"
}
