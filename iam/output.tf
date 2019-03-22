####################################################
# IAM - Application specific
####################################################
# INTERNAL

# case notes
output "iam_case_notes_app_role_name" {
  value = "${module.create-iam-app-role-int-case-notes.iamrole_name}"
}

output "iam_case_notes_app_role_arn" {
  value = "${module.create-iam-app-role-int-case-notes.iamrole_arn}"
}

# PROFILE
output "iam_case_notes_app_instance_profile_name" {
  value = "${module.create-iam-instance-profile-int-case-notes.iam_instance_name}"
}

# ECS
output "iam_role_int_ecs_role_arn" {
  value = "${module.create-iam-ecs-role-int.iamrole_arn}"
}

output "iam_role_int_ecs_role_name" {
  value = "${module.create-iam-ecs-role-int.iamrole_name}"
}
