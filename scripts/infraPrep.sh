#!/bin/bash
echo $(date) " - Starting Node Prep Script"

export USERNAME_ORG=$1
export PASSWORD_ACT_KEY="$2"
export POOL_ID=$3

# Remove RHUI

rm -f /etc/yum.repos.d/rh-cloud.repo
sleep 10

# Install base packages and update system to latest packages
echo $(date) " - Install base packages and update system to latest packages"

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct
yum -y install cloud-utils-growpart.noarch
yum -y install ansible
yum -y update glusterfs-fuse
yum -y update --exclude=WALinuxAgent
echo $(date) " - Base package insallation and updates complete"

# Grow Root File System
echo $(date) " - Grow Root FS"

rootdev=`findmnt --target / -o SOURCE -n`
rootdrivename=`lsblk -no pkname $rootdev`
rootdrive="/dev/"$rootdrivename
name=`lsblk  $rootdev -o NAME | tail -1`
part_number=${name#*${rootdrivename}}

growpart $rootdrive $part_number -u on
xfs_growfs $rootdev

# Install Docker
echo $(date) " - Installing Docker"
yum -y install docker

# Update docker config for insecure registry
echo "
# Adding insecure-registry option required by OpenShift
OPTIONS=\"\$OPTIONS --insecure-registry 172.30.0.0/16\"
" >> /etc/sysconfig/docker

# Create thin pool logical volume for Docker
echo $(date) " - Creating thin pool logical volume for Docker and starting service"

DOCKERVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 | head -n1 )

echo "
# Adding OpenShift data disk for docker
DEVS=${DOCKERVG}
VG=docker-vg
" >> /etc/sysconfig/docker-storage-setup

# Running setup for docker storage
docker-storage-setup
if [ $? -eq 0 ]
then
    echo "Docker thin pool logical volume created successfully"
else
    echo "Error creating logical volume for Docker"
    exit 5
fi

# Enable and start Docker services

systemctl enable docker
systemctl start docker

echo $(date) " - Script Complete"

