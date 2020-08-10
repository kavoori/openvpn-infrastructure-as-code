#!/bin/bash
# Developed by: Rabi Kavoori
# This script deletes the VPC and all its sub resources and also terminiates the OpenVPN instance if it is running 
# Requirements : AWS CLI to be available in the path and credentials that can delete VPC resources
# Input : AWS Region ID
# This script does not delete the AMI created by Packer

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

if [ "$#" -ne 2 ]; then
	LOG="============================================================="; write_log
	LOG="Illegal number of parameters. Script requires the name of the region"; write_log
  LOG="Usage: $0 <vpc-prefix> <region-name>"; write_log
  LOG="============================================================="; write_log
  exit 1
fi

VPC_PREFIX=$1
REGION=$2
VPC_NAME=$VPC_PREFIX-$REGION
APP_NAME="OpenVPN"

LOG="============================================================="; write_log
VPC_ID=$(aws --region $REGION ec2 describe-vpcs --filter Name=tag:Name,Values=$VPC_NAME --output text --query 'Vpcs[0].VpcId')
LOG="Checking for any VPCs (non-default) for this region that is tagged with $VPC_NAME ..." ; write_log
if [ "$VPC_ID" != "None" ];
then
    LOG="Found the VPC (non-default) for this region that is tagged with $VPC_NAME : $VPC_ID" ; write_log
    LOG="Checking if OpenVPN instance is running in $VPC_ID" ; write_log
    RUNNING_INSTANCE=$(aws --region $REGION ec2 describe-instances --filters Name=vpc-id,Values=$VPC_ID Name=instance-state-code,Values=16 Name=tag:App,Values=$APP_NAME --output text --query 'Reservations[*].Instances[*].InstanceId')
    
    if [[ $RUNNING_INSTANCE = *[!\ ]* ]];
    then
          LOG="Instance running OpenVPN is running in $VPC_ID with ID : $RUNNING_INSTANCE " ; write_log
          LOG="Terminating instance with ID : $RUNNING_INSTANCE " ; write_log
          DROP_OUTPUT=$(aws --region $REGION ec2 terminate-instances --instance-ids $RUNNING_INSTANCE)
    
          LOG="Waiting for instance to terminate with ID : $RUNNING_INSTANCE ...." ; write_log
          aws --region $REGION ec2 wait instance-terminated --instance-ids $RUNNING_INSTANCE
          LOG="Instance terminated with ID : $RUNNING_INSTANCE" ; write_log
    else
          LOG="No instances with App OpenVPN are running in $VPC_ID. Proceeding with deleting next set of resources..." ; write_log
    fi
    
    SG_NAME="VPN-SG-for-"$VPC_ID # Convention followed during creation
    SG_ID=$(aws --region $REGION ec2 describe-security-groups --filter Name=vpc-id,Values=$VPC_ID Name=group-name,Values=$SG_NAME  --query 'SecurityGroups[*].GroupId' --output text)
    if [[ $SG_ID = *[!\ ]* ]];
    then
         LOG="Deleting security Groups $SG_ID with group name $SG_NAME in VPC : $VPC_ID in Region $REGION"; write_log
         aws --region $REGION ec2 delete-security-group --group-id $SG_ID
    fi
    
    PUB_SUBNET_ID=$(aws --region $REGION ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=PublicSubnet --query 'Subnets[*].SubnetId' --output text)
    if [[ $PUB_SUBNET_ID = *[!\ ]* ]];
    then
         LOG="Deleting Public Subnets $PUB_SUBNET_ID in VPC : $VPC_ID in Region $REGION"; write_log
         aws --region $REGION ec2 delete-subnet --subnet-id $PUB_SUBNET_ID 
    fi
    
    PRIVATE_SUBNET_ID=$(aws --region $REGION ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=PrivateSubnet --query 'Subnets[*].SubnetId' --output text)
    if [[ $PRIVATE_SUBNET_ID = *[!\ ]* ]];
    then
        LOG="Deleting Private Subnets $PRIVATE_SUBNET_ID in VPC : $VPC_ID in Region $REGION"; write_log
        aws --region $REGION ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_ID
    fi
    
    
    CUSTOM_RTB=$(aws --region $REGION ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=CustomRouteTable --query 'RouteTables[*].RouteTableId' --output text)
    if [[ $CUSTOM_RTB = *[!\ ]* ]];
    then
        LOG="Deleting Custom Route table $CUSTOM_RTB in VPC : $VPC_ID in Region $REGION"; write_log
        aws --region $REGION ec2 delete-route-table --route-table-id $CUSTOM_RTB
    fi
    
    IGW=$(aws --region $REGION ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC_ID --query 'InternetGateways[*].InternetGatewayId' --output text)
    if [[ $IGW = *[!\ ]* ]];
    then
        LOG="Detaching Internet Gateway $IGW in  VPC : $VPC_ID in Region $REGION"; write_log
        aws --region $REGION ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID
        LOG="Deleting Internet Gateway $IGW in  VPC : $VPC_ID in Region $REGION"; write_log
        aws --region $REGION ec2 delete-internet-gateway --internet-gateway-id $IGW
    fi
    
    LOG="Finally deleting $VPC_ID in Region $REGION"; write_log
    aws --region $REGION ec2 delete-vpc --vpc-id $VPC_ID
    
    LOG="Done deleting VPC  with name $VPC_NAME with ID : $VPC_ID in Region $REGION"; write_log
    LOG="============================================================="; write_log
else
  LOG="No VPCs with $VPC_NAME found in Region $REGION to delete. Done with the script"; write_log
fi
LOG="============================================================="; write_log

