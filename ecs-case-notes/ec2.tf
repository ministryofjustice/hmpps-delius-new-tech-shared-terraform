# LOCALS
locals {
  device_name   = "/dev/xvdb"
  volume_size   = "100"
  instance_type = "t2.medium"
  service       = "mongodb"
}

#-------------------------------------------------------------
### Getting the latest centos ami
#-------------------------------------------------------------
data "aws_ami" "centos_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["HMPPS Base Docker Centos master*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["${data.terraform_remote_state.common.common_account_id}", "895523100917"] # MOJ
}

###############################################
# MONGODB DB PASSWORD
###############################################
resource "random_string" "mongodb_password" {
  length  = 20
  special = true
}

# Add to SSM
resource "aws_ssm_parameter" "param" {
  name        = "${local.common_name}-${local.application}-root-user-password"
  description = "${local.common_name}-${local.application}-root-user-password"
  type        = "SecureString"
  value       = "${sha256(bcrypt(random_string.mongodb_password.result))}"

  tags = "${merge(local.tags, map("Name", "${local.common_name}-${local.application}-root-user-password"))}"

  lifecycle {
    ignore_changes = ["value"]
  }
}

#-------------------------------------------------------------
### Create primary 
#-------------------------------------------------------------

data "template_file" "userdata" {
  template = "${file("../userdata/mongodb-userdata.sh")}"

  vars {
    app_name             = "${local.app_name}"
    bastion_inventory    = "${local.bastion_inventory}"
    env_identifier       = "${local.environment_identifier}"
    short_env_identifier = "${local.short_environment_identifier}"
    route53_sub_domain   = "${local.environment}.${local.app_name}"
    container_name       = "${local.service}"
    private_domain       = "${local.internal_domain}"
    account_id           = "${local.account_id}"
    internal_domain      = "${local.internal_domain}"
    environment          = "${local.environment}"
    common_name          = "${local.common_name}"
    data_disk            = "${local.device_name}"
    log_group_name       = "${module.create_loggroup.loggroup_name}"
    image_url            = "${local.image_url}"
  }
}

#-------------------------------------------------------------
### Create instance
#-------------------------------------------------------------
module "create-ec2-instance" {
  source                      = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//ec2_no_replace_instance"
  app_name                    = "${local.application}-${local.service}"
  ami_id                      = "${data.aws_ami.centos_ami.id}"
  instance_type               = "${local.instance_type}"
  subnet_id                   = "${local.db_subnet_ids[1]}"
  iam_instance_profile        = "${local.instance_profile}"
  associate_public_ip_address = false
  monitoring                  = true
  user_data                   = "${data.template_file.userdata.rendered}"
  CreateSnapshot              = true
  tags                        = "${local.tags}"
  key_name                    = "${local.ssh_deployer_key}"
  vpc_security_group_ids      = ["${local.mongodb_security_groups}"]
}

#-------------------------------------------------------------
### EBS Volumes
#-------------------------------------------------------------
module "create-ebs-volume" {
  source            = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//ebs//ebs_volume"
  CreateSnapshot    = true
  tags              = "${local.tags}"
  availability_zone = "${local.availability_zone_map["az2"]}"
  volume_size       = "${local.volume_size}"
  encrypted         = true
  app_name          = "${local.application}-${local.service}"
}

module "attach-ebs-volume" {
  source      = "git::https://github.com/ministryofjustice/hmpps-terraform-modules.git?ref=master//modules//ebs//ebs_attachment"
  device_name = "${local.device_name}"
  instance_id = "${module.create-ec2-instance.instance_id}"
  volume_id   = "${module.create-ebs-volume.id}"
}

#-------------------------------------------------------------
# Create route53 entry for instance 1
#-------------------------------------------------------------

resource "aws_route53_record" "mongodb" {
  zone_id = "${local.private_zone_id}"
  name    = "${local.application}-${local.service}.${local.internal_domain}"
  type    = "A"
  ttl     = "300"
  records = ["${module.create-ec2-instance.private_ip}"]
}
