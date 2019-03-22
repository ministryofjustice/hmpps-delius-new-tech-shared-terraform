#-------------------------------------------------------------
### INTERNAL IAM POLICES FOR EC2 RUNNING ECS SERVICES
#-------------------------------------------------------------

data "template_file" "iam_policy_app_int-case-notes" {
  template = "${file("../policies/case_notes_ec2_internal_policy.json")}"

  vars {
    s3-config-bucket = "${local.s3-config-bucket}"
    app_role_arn     = "${module.create-iam-app-role-int-case-notes.iamrole_arn}"
  }
}

module "create-iam-app-role-int-case-notes" {
  source     = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=pre-shared-vpc//modules//iam//role"
  rolename   = "${local.common_name}-case-notes-ec2"
  policyfile = "ec2_policy.json"
}

module "create-iam-instance-profile-int-case-notes" {
  source = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=pre-shared-vpc//modules//iam//instance_profile"
  role   = "${module.create-iam-app-role-int-case-notes.iamrole_name}"
}

module "create-iam-app-policy-int-case-notes" {
  source     = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=pre-shared-vpc//modules//iam//rolepolicy"
  policyfile = "${data.template_file.iam_policy_app_int-case-notes.rendered}"
  rolename   = "${module.create-iam-app-role-int-case-notes.iamrole_name}"
}
