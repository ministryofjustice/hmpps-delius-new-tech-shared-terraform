# SECURITY GROUPS
output "security_groups_map" {
  value = "${local.sg_map_ids}"
}

# case notes
output "security_groups_sg_case_notes_api_in" {
  value = "${local.sg_case_notes_api_in}"
}

output "security_groups_sg_case_notes_mongodb_db_in" {
  value = "${local.sg_case_notes_mongodb_db_in}"
}

output "security_groups_sg_case_notes_external_lb_in" {
  value = "${local.sg_case_notes_external_lb_in}"
}
