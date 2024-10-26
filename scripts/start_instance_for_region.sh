#!/bin/bash
# Developed by: Rabi Kavoori
# This script starts an instance with an AMI created by packer and openVPN software provisioned by packer (in a previous step)
# This script also creates any security groups necessary for OpenVPN and assigns it to the instance
# Requirements : AWS CLI to be available in the path and credentials that start instances
# Input : VPC Prefix
# Input : AWS Region ID

# Date and time variables
DATE=`date +%Y-%m-%d`
TIME=`date +%H-%M-%S`
TODAY=$DATE"T"$TIME

SELF="${0##*/}"
SELF_NO_EXT=$(basename "$0" .sh)

timestamp() {
  TIMESTAMP=`date -u +"%Y-%m-%dT%H:%M:%S.000Z"`
}

write_log() {
  timestamp
  echo "${TIMESTAMP} - ${LOG}" 2>&1
}

if [ "$#" -ne 3 ]; then
  LOG="============================================================="; write_log
  LOG="Illegal number of parameters. Script requires three parameters"; write_log
  LOG="Usage: $0 <vpc-prefix> <region-name> <key-name>"; write_log
  LOG="============================================================="; write_log
  exit 1
fi

VPC_PREFIX=$1
REGION=$2
KEY_NAME=$3
VPC_NAME=$VPC_PREFIX-$REGION
APP_NAME="OpenVPN"

LOG="============================================================="; write_log
VPC_ID=$(aws --region $REGION ec2 describe-vpcs --filter Name=tag:Name,Values=$VPC_NAME --output text --query 'Vpcs[0].VpcId')
LOG="Found the VPC (non-default) for this region that is tagged with $VPC_NAME : $VPC_ID" ; write_log

AMI_ID=$(aws --region $REGION ec2 describe-images --filter Name=tag:image_app,Values=$APP_NAME --output text --query 'Images[0].ImageId')
LOG="Found the AMI for this region that is tagged with $APP_NAME : $AMI_ID" ; write_log

PUB_SUBNET_ID=$(aws --region $REGION ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=PublicSubnet --output text --query 'Subnets[*].SubnetId')
LOG="Found the Public Subnet for this VPC : $PUB_SUBNET_ID" ; write_log

SG_NAME="VPN-SG"-for-$VPC_ID
LOG="Creating a Security Group for the VPC $VPC_ID with the name $SG_NAME" ; write_log
SG_ID=$(aws --region $REGION ec2 create-security-group --group-name $SG_NAME --description "VPN security group" --vpc-id $VPC_ID --output text --query 'GroupId')
LOG="Security Group created : $SG_ID" ; write_log

LOG="Authorizing security-group-ingress for $SG_ID for tcp port 22, 943, 1194 (vpn) 443, 8" ; write_log
aws --region $REGION ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws --region $REGION ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 943 --cidr 0.0.0.0/0
aws --region $REGION ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 1194 --cidr 0.0.0.0/0
aws --region $REGION ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
aws --region $REGION ec2 authorize-security-group-ingress --group-id $SG_ID --protocol icmp --port 8 --cidr 0.0.0.0/0

LOG="Starting the EC2 instance with AMI: $AMI_ID"; write_log
INSTANCE_ID=$(aws --region $REGION  ec2 run-instances --image-id $AMI_ID --key-name $KEY_NAME --count 1 --instance-type t2.micro --security-group-ids $SG_ID --subnet-id $PUB_SUBNET_ID --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=OpenVPN from AMI created by Packer}]' --associate-public-ip-address --query 'Instances[0].InstanceId' --output=text)

if [ -z "$INSTANCE_ID" ]
then
	LOG="Unable to determine Instance ID or unable to start Instance. Exiting"; write_log
	LOG="============================================================="; write_log
	exit 1
else
	LOG="Waiting for instance $INSTANCE_ID to start.... "; write_log
	aws --region $REGION ec2 wait instance-running --instance-ids $INSTANCE_ID
	LOG="Checking if the instance is up and running..." ; write_log

	EC2_INSTANCE_STATE_OUTPUT=$(aws --region $REGION ec2 describe-instance-status --instance-id $INSTANCE_ID)
	EC2_INSTANCE_STATE_CODE=$(echo "$EC2_INSTANCE_STATE_OUTPUT" | python3 -c "import sys, json; print(json.load(sys.stdin)['InstanceStatuses'][0]['InstanceState']['Code'])")
	EC2_INSTANCE_STATE_NAME=$(echo "$EC2_INSTANCE_STATE_OUTPUT" | python3 -c "import sys, json; print(json.load(sys.stdin)['InstanceStatuses'][0]['InstanceState']['Name'])")
	LOG="Instance State : $EC2_INSTANCE_STATE_NAME, Instance State code : $EC2_INSTANCE_STATE_CODE"; write_log

	aws --region $REGION ec2 create-tags --resources $INSTANCE_ID --tags Key=App,Value=$APP_NAME

	LOG="Run Describe instance to get Public IP address"; write_log
	PUBLIC_IP=$(aws --region $REGION ec2 describe-instances --filters Name=vpc-id,Values=$VPC_ID --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].PublicIpAddress' --output=text)
	LOG="Public IP found from the running instance : $PUBLIC_IP"; write_log
	LOG="============================================================="; write_log
fi
