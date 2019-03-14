terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "s3" {}
}

provider "aws" {
  region  = "${var.region}"
  version = "~> 1.16"
}

####################################################
# DATA SOURCE MODULES FROM OTHER TERRAFORM BACKENDS
####################################################
#-------------------------------------------------------------
### Getting the common details
#-------------------------------------------------------------
data "terraform_remote_state" "common" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket_name}"
    key    = "iaps/common/terraform.tfstate"
    region = "${var.region}"
  }
}

####################################################
# Locals
####################################################

locals {
  vpc_id                 = "${data.terraform_remote_state.common.vpc_id}"
  cidr_block             = "${data.terraform_remote_state.common.vpc_cidr_block}"
  common_name            = "${data.terraform_remote_state.common.common_name}"
  region                 = "${data.terraform_remote_state.common.region}"
  app_name               = "${data.terraform_remote_state.common.app_name}"
  environment_identifier = "${data.terraform_remote_state.common.environment_identifier}"
  environment            = "${data.terraform_remote_state.common.environment}"
  tags                   = "${data.terraform_remote_state.common.common_tags}"
  public_cidr_block      = ["${data.terraform_remote_state.common.db_cidr_block}"]
  private_cidr_block     = ["${data.terraform_remote_state.common.private_cidr_block}"]
  db_cidr_block          = ["${data.terraform_remote_state.common.db_cidr_block}"]
  sg_map_ids             = "${data.terraform_remote_state.common.sg_map_ids}"

  user_access_cidr_blocks = [
    "${var.user_access_cidr_blocks}",
    "${data.terraform_remote_state.common.nat_gateway_ips}",
  ]

  bastion_cidr_block           = ["${data.terraform_remote_state.common.bastion_vpc_public_cidr}"]
  sg_case_notes_api_in         = "${data.terraform_remote_state.common.sg_map_ids["sg_case_notes_api_in"]}"
  sg_case_notes_mongodb_db_in  = "${data.terraform_remote_state.common.sg_map_ids["sg_case_notes_mongodb_db_in"]}"
  sg_case_notes_external_lb_in = "${data.terraform_remote_state.common.sg_map_ids["sg_case_notes_external_lb_in"]}"
}

#######################################
# SECURITY GROUPS
#######################################
#-------------------------------------------------------------
### external lb sg
#-------------------------------------------------------------

resource "aws_security_group_rule" "external_lb_ingress_http" {
  security_group_id = "${local.sg_case_notes_external_lb_in}"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  type              = "ingress"
  description       = "${local.common_name}-lb-external-sg-http"

  cidr_blocks = [
    "${local.user_access_cidr_blocks}",
  ]
}

resource "aws_security_group_rule" "external_lb_ingress_https" {
  security_group_id = "${local.sg_case_notes_external_lb_in}"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  type              = "ingress"
  description       = "${local.common_name}-lb-external-sg-https"

  cidr_blocks = [
    "${local.user_access_cidr_blocks}",
  ]
}

resource "aws_security_group_rule" "external_lb_egress_http" {
  security_group_id        = "${local.sg_case_notes_external_lb_in}"
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = "${local.sg_case_notes_api_in}"
  description              = "${local.common_name}-instance-internal-http"
}

resource "aws_security_group_rule" "external_lb_egress_https" {
  security_group_id        = "${local.sg_case_notes_external_lb_in}"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${local.sg_case_notes_api_in}"
  description              = "${local.common_name}-instance-internal-https"
}

#-------------------------------------------------------------
### internal instance sg
#-------------------------------------------------------------
resource "aws_security_group_rule" "internal_lb_ingress_http" {
  security_group_id        = "${local.sg_case_notes_api_in}"
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = "${local.sg_case_notes_external_lb_in}"
  description              = "${local.common_name}-lb-ingress-http"
}

resource "aws_security_group_rule" "internal_lb_ingress_https" {
  security_group_id        = "${local.sg_case_notes_api_in}"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${local.sg_case_notes_external_lb_in}"
  description              = "${local.common_name}-lb-ingress-https"
}

resource "aws_security_group_rule" "internal_inst_sg_ingress_self" {
  security_group_id = "${local.sg_case_notes_api_in}"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  self              = true
}

resource "aws_security_group_rule" "internal_inst_sg_egress_self" {
  security_group_id = "${local.sg_case_notes_api_in}"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  self              = true
}

resource "aws_security_group_rule" "internal_inst_sg_egress_mongodb" {
  security_group_id        = "${local.sg_case_notes_api_in}"
  type                     = "egress"
  from_port                = "27017"
  to_port                  = "27017"
  protocol                 = "tcp"
  source_security_group_id = "${local.sg_case_notes_mongodb_db_in}"
  description              = "${local.common_name}-mongodb-sg"
}

#-------------------------------------------------------------
### mongodb sg
#-------------------------------------------------------------
resource "aws_security_group_rule" "mongodb_sg_egress_mongodb" {
  security_group_id        = "${local.sg_case_notes_mongodb_db_in}"
  type                     = "ingress"
  from_port                = "27017"
  to_port                  = "27017"
  protocol                 = "tcp"
  source_security_group_id = "${local.sg_case_notes_api_in}"
  description              = "${local.common_name}-mongodb-sg"
}
