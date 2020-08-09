#!/bin/bash
# Developed by: Rabi Kavoori - rabi@kavoori.com
# This script queries the running instance to get the public IP address and updates Route53 record for dns name with that IP
# Requirements : AWS CLI to be available in the path and credentials that start instances 
# Input : VPC Prefix
# Input : AWS Region ID
# Input : Route53 Hosted Zone ID
# Input : dns name for the instance

# Date and time variables
DATE=`date +%Y-%m-%d`
TIME=`date +%H-%M-%S`
TODAY=$DATE"T"$TIME


SELF="${0##*/}"
SELF_NO_EXT=$(basename "$0" .sh)
MY_DIR=`dirname $0`

RECORD_SET_UPDATE_FILE_TEMPLATE="$MY_DIR/change-resource-record-sets_template.json"
RECORD_SET_UPDATE_FILE="$MY_DIR/change-resource-record-sets.json"
UPSERT_RESULT_FILE="$MY_DIR/upsert_result.json"

timestamp() {
  TIMESTAMP=`date -u +"%Y-%m-%dT%H:%M:%S.000Z"`
}

write_log() {
  timestamp
  echo "${TIMESTAMP} - ${LOG}" 2>&1
}

if [ "$#" -ne 4 ]; then
  LOG="============================================================="; write_log
  LOG="Illegal number of parameters. Script requires the name of the region"; write_log
  LOG="Usage: $0 <vpc-prefix> <region-name> <hosted-zone-id> <dns-name>"; write_log
  LOG="============================================================="; write_log
  exit 1
fi

VPC_PREFIX=$1
REGION=$2
HOSTED_ZONE_ID=$3
DNS_NAME=$4

VPC_NAME=$VPC_PREFIX-$REGION
APP_NAME="OpenVPN"

LOG="============================================================="; write_log
VPC_ID=$(aws --region $REGION ec2 describe-vpcs --filter Name=tag:Name,Values=$VPC_NAME --output text --query 'Vpcs[0].VpcId')
#'ResourceType=instance,Tags=[{Key=Name,Value=OpenVPN from AMI created by Packer}]'
#The following needs to be tested
INSTANCE_ID=$(aws --region $REGION  ec2 describe-instances --filters Name=vpc-id,Values=$VPC_NAME --filters "Name=tag:App,Values=OpenVPN" --filters Name=instance-state-name,Values=running --query 'Reservations[0].Instances[0].InstanceId' --output=text)

LOG="Run Describe instance to get Public IP address"; write_log
PUBLIC_IP=$(aws --region $REGION ec2 describe-instances --filters Name=vpc-id,Values=$VPC_ID --filters "Name=tag:App,Values=OpenVPN" --filters Name=instance-state-name,Values=running --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].PublicIpAddress' --output=text)
LOG="Public IP found from the running instance : $PUBLIC_IP"; write_log

LOG="Creating a change-resource-record-sets file"; write_log
echo $LOG
sed -e "s/\${newIPAddress}/$PUBLIC_IP/g" -e "s/\${dnsName}/$DNS_NAME/g" $RECORD_SET_UPDATE_FILE_TEMPLATE > $RECORD_SET_UPDATE_FILE
LOG=`cat $RECORD_SET_UPDATE_FILE`; write_log
LOG="Calling route53 to upsert A record for Hosted Zone ID : $HOSTED_ZONE_ID"; write_log
echo $LOG
ROUTE53_UPSERT_RESULT=$(aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file://$RECORD_SET_UPDATE_FILE)
LOG="UPSERT Result : $ROUTE53_UPSERT_RESULT"; write_log
echo $ROUTE53_UPSERT_RESULT > $UPSERT_RESULT_FILE
ROUTE53_CHANGE_ID=$(cat $UPSERT_RESULT_FILE | python3 -c "import sys, json; print(json.load(sys.stdin)['ChangeInfo']['Id'])")
LOG="change ID for the upsert : $ROUTE53_CHANGE_ID"; write_log
LOG="Waiting for resource-record-sets-changed status to be INSYNC : $ROUTE53_CHANGE_ID" ; write_log
echo $LOG
aws route53 wait resource-record-sets-changed --id $ROUTE53_CHANGE_ID
LOG="Checking the status of the change..... : $ROUTE53_CHANGE_ID" ; write_log
echo $LOG
ROUTE53_CHANGE_STATUS_OUTPUT=$(aws route53 get-change --id $ROUTE53_CHANGE_ID)
ROUTE53_CHANGE_STATUS=$(echo "$ROUTE53_CHANGE_STATUS_OUTPUT" | python3 -c "import sys, json; print(json.load(sys.stdin)['ChangeInfo']['Status'])")
LOG="Status of the change : $ROUTE53_CHANGE_STATUS" ; write_log
echo $LOG
LOG="============================================================="; write_log
