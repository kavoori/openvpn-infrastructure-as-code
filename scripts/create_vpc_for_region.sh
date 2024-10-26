#!/bin/bash
# Developed by: Rabi Kavoori
# This script creates a VPC and a two subnets so that Packer can use to launch a temporary instance to create an AMI. 
# Requirements : AWS CLI to be available in the path and credentials that can create VPC resources
# Input : VPC Prefix
# Input : AWS Region ID
# This script does not create an AMI

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
  LOG="Illegal number of parameters. Script requires two parameters"; write_log
  LOG="Usage: $0 <vpc-prefix> <region-name>"; write_log
  LOG="============================================================="; write_log
  exit 1
fi

VPC_PREFIX=$1
REGION=$2
VPC_NAME=$VPC_PREFIX-$REGION

LOG="============================================================="; write_log
LOG="Creating VPC : $VPC_NAME in Region $REGION"; write_log
VPC_ID=$(aws --region $REGION ec2 create-vpc --cidr-block 10.0.0.0/26 --output text --query 'Vpc.VpcId')

LOG="Waiting for VPC : $VPC_ID to be available"; write_log
aws --region $REGION ec2 wait vpc-available --vpc-ids $VPC_ID
LOG="VPC : $VPC_ID now available"; write_log

LOG="Tagging VPC : $VPC_ID with VPC NAME : $VPC_NAME"; write_log
aws --region $REGION ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
aws --region $REGION ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws --region $REGION ec2 create-tags --resources $VPC_ID --tags Key=vpcname,Value=$VPC_NAME Key=Name,Value=$VPC_NAME

LOG="Creating public subnet for VPC_ID : $VPC_ID"; write_log
PUB_SUBNET_ID=$(aws --region $REGION ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.0.0/27 --output text --query 'Subnet.SubnetId')

LOG="Creating private subnet for VPC_ID : $VPC_ID"; write_log
PRIV_SUBNET_ID=$(aws --region $REGION ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.0.32/27 --output text --query 'Subnet.SubnetId')

LOG="Waiting for public subnet $PUB_SUBNET_ID and private subnet $PRIV_SUBNET_ID to be available"; write_log
aws --region $REGION ec2 wait subnet-available --subnet-ids $PUB_SUBNET_ID $PRIV_SUBNET_ID

LOG="Tagging public subnet $PUB_SUBNET_ID and private subnet $PRIV_SUBNET_ID with names"; write_log
aws --region $REGION ec2 create-tags --resources $PUB_SUBNET_ID --tags Key=Name,Value=PublicSubnet
aws --region $REGION ec2 create-tags --resources $PRIV_SUBNET_ID --tags Key=Name,Value=PrivateSubnet


LOG="Creating InternetGateway for VPC_ID : $VPC_ID in region $REGION"; write_log
IGW_ID=$(aws --region $REGION ec2 create-internet-gateway --output text --query 'InternetGateway.InternetGatewayId')
aws --region $REGION ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=$VPC_PREFIX-IGW

LOG="Attaching InternetGateway : $IGW_ID to VPC_ID : $VPC_ID in region $REGION"; write_log
aws --region $REGION ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

LOG="Getting the Main route table for VPC_ID : $VPC_ID in region $REGION"; write_log
MAIN_RTB=$(aws --region $REGION  ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" --output text --query 'RouteTables[*].RouteTableId')
LOG="Main route table is : $MAIN_RTB for VPC_ID : $VPC_ID in region $REGION"; write_log

LOG="Create a custom route table to VPC_ID : $VPC_ID in region $REGION"; write_log
CUST_RTB=$(aws --region $REGION ec2 create-route-table --vpc-id $VPC_ID --output text --query 'RouteTable.RouteTableId')

LOG="Tagging main route table $MAIN_RTB and custom route table $CUST_RTB with names"; write_log
aws --region $REGION ec2 create-tags --resources $MAIN_RTB --tags Key=Name,Value=MainRouteTable
aws --region $REGION ec2 create-tags --resources $CUST_RTB --tags Key=Name,Value=CustomRouteTable

LOG="Create a route in custom route table $CUST_RTB that points all traffic (0.0.0.0/0) to the Internet gateway"; write_log
ROUTE_CREATED=$(aws --region $REGION ec2 create-route --route-table-id $CUST_RTB --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID)

LOG="Associate the custom route table $CUST_RTB to public subnet $PUB_SUBNET_ID"; write_log
ASSOCIATION_RESULT=$(aws --region $REGION ec2 associate-route-table  --subnet-id $PUB_SUBNET_ID --route-table-id $CUST_RTB)

LOG="Let instances in public subnet $PUB_SUBNET_ID automatically receives a public IP address"; write_log
aws --region $REGION ec2 modify-subnet-attribute --subnet-id $PUB_SUBNET_ID --map-public-ip-on-launch

LOG="Done creating VPC  with name $VPC_NAME with ID : $VPC_ID in Region $REGION"; write_log
LOG="============================================================="; write_log