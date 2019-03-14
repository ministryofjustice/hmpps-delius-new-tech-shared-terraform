locals {
  ecs_role_policy_file = "${file("../policies/ecs_role_policy.json")}"
  ecs_policy_file      = "ecs_policy.json"
}

#-------------------------------------------------------------
### INTERNAL IAM POLICES FOR ECS SERVICES
#-------------------------------------------------------------

data "template_file" "iam_policy_ecs_int" {
  template = "${local.ecs_role_policy_file}"

  vars {
    aws_lb_arn = "*"
  }
}

module "create-iam-ecs-role-int" {
  source     = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//iam//role"
  rolename   = "${local.common_name}-int-ecs-svc"
  policyfile = "${local.ecs_policy_file}"
}

module "create-iam-ecs-policy-int" {
  source     = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//iam//rolepolicy"
  policyfile = "${data.template_file.iam_policy_ecs_int.rendered}"
  rolename   = "${module.create-iam-ecs-role-int.iamrole_name}"
}
