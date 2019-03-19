#!/usr/bin/env bash

yum install -y python-pip git wget

cat << EOF >> /etc/environment
HMPPS_ROLE=${app_name}
HMPPS_FQDN=${app_name}.${private_domain}
HMPPS_STACKNAME=${env_identifier}
HMPPS_STACK="${short_env_identifier}"
HMPPS_ENVIRONMENT=${route53_sub_domain}
HMPPS_ACCOUNT_ID="${account_id}"
HMPPS_DOMAIN="${private_domain}"
EOF
## Ansible runs in the same shell that has just set the env vars for future logins so it has no knowledge of the vars we've
## just configured, so lets export them
export HMPPS_ROLE="${app_name}"
export HMPPS_FQDN="${app_name}.${private_domain}"
export HMPPS_STACKNAME="${env_identifier}"
export HMPPS_STACK="${short_env_identifier}"
export HMPPS_ENVIRONMENT=${route53_sub_domain}
export HMPPS_ACCOUNT_ID="${account_id}"
export HMPPS_DOMAIN="${private_domain}"

cd ~
pip install ansible

cat << EOF > ~/requirements.yml
- name: bootstrap
  src: https://github.com/ministryofjustice/hmpps-bootstrap
  version: centos
- name: rsyslog
  src: https://github.com/ministryofjustice/hmpps-rsyslog-role
- name: elasticbeats
  src: https://github.com/ministryofjustice/hmpps-beats-monitoring
- name: users
  src: singleplatform-eng.users
EOF

wget https://raw.githubusercontent.com/ministryofjustice/hmpps-delius-ansible/master/group_vars/${bastion_inventory}.yml -O users.yml

cat << EOF > ~/bootstrap.yml
---
- hosts: localhost
  vars_files:
   - "{{ playbook_dir }}/users.yml"
  roles:
     - bootstrap
     - rsyslog
     - users
EOF

ansible-galaxy install -f -r ~/requirements.yml
ansible-playbook ~/bootstrap.yml

# Install awslogs and the jq JSON parser
yum install -y lvm2

current_dir=$(pwd)
region=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

mkdir -p /tmp/awslogs-install
cd /tmp/awslogs-install
curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O

mkdir -p /var/log/${container_name}

# Inject the CloudWatch Logs configuration file contents
cat > awslogs.conf <<- EOF
[general]
state_file = /var/awslogs/state/agent-state
[/var/log/messages]
datetime_format = %b %d %H:%M:%S
file = /var/log/messages
buffer_duration = 5000
log_stream_name = {instance_id}/messages
initial_position = start_of_file
log_group_name = ${log_group_name}
[/var/log/audit/audit.log]
datetime_format = %b %d %H:%M:%S
file = /var/log/audit/audit.log
buffer_duration = 5000
log_stream_name = {instance_id}/audit
initial_position = start_of_file
log_group_name = ${log_group_name}
[/var/log/secure]
datetime_format = %b %d %H:%M:%S
file = /var/log/secure
buffer_duration = 5000
log_stream_name = {instance_id}/secure
initial_position = start_of_file
log_group_name = ${log_group_name}
[/var/log/cloud-init.log]
datetime_format = %b %d %H:%M:%S
file = /var/log/cloud-init.log
buffer_duration = 5000
log_stream_name = {instance_id}/cloud-init.log
initial_position = start_of_file
log_group_name = ${log_group_name}
EOF

python ./awslogs-agent-setup.py --region $region --non-interactive --configfile=awslogs.conf

systemctl daemon-reload
systemctl enable awslogs
systemctl start awslogs
# end script

cd $current_dir

rm -rf /tmp/awslogs-install

###############################################
# MONGO SECTION
###############################################
yum install -y lvm2

blockdev --setra 0 ${data_disk}

echo 'ACTION=="add|change", KERNEL=="xvdc", ATTR{bdi/read_ahead_kb}="0"' | tee -a /etc/udev/rules.d/85-ebs.rules

vgcreate data ${data_disk}
lvcreate -L 30G -n mongodb_lv data
lvcreate -L 30G -n backups_lv data

mkdir -p /opt/mongodb/data \
  /opt/mongodb/backups \
  /var/log/mongodb

chown -R mongodb:mongodb /opt/mongodb /var/log/mongodb

mkfs.xfs /dev/data/mongodb_lv
mkfs.xfs /dev/data/backups_lv

mount -t xfs /dev/mapper/data-mongodb_lv /opt/mongodb/data
mount -t xfs /dev/data/backups_lv /opt/mongodb/backups

echo '* soft nofile 64000
* hard nofile 64000
* soft nproc 64000
* hard nproc 64000' | tee /etc/security/limits.d/90-mongodb.conf

mount /opt/mongodb/data
mount /opt/mongodb/backups

# Add mongodb container
echo '[Unit]
Description=${container_name} mongodb container
After=docker.service
Requires=docker.service
[Service]
EnvironmentFile=-/etc/sysconfig/mongodb
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop ${container_name}
ExecStartPre=-/usr/bin/docker rm ${container_name}
ExecStartPre=-/usr/bin/docker pull ${image_url}
ExecStart=/usr/bin/docker run --name ${container_name} \
  -p 27017:27017 \
  -v /opt/mongodb/data:/data/db:z \
  -v /opt/mongodb/backups:/opt/backups:z \
  -e "TZ=Europe/London" \
  -e "MONGO_INITDB_ROOT_USERNAME=${mongodb_root_user}" \
  -e "MONGO_INITDB_ROOT_PASSWORD=${mongodb_root_user}" ${image_url}
ExecStop=-/usr/bin/docker rm -f ${container_name}
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/mongodb.service

touch /etc/sysconfig/mongodb
systemctl daemon-reload
systemctl enable mongodb.service
systemctl start mongodb.service