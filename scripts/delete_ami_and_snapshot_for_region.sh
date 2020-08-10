#!/bin/bash
# Developed by: Rabi Kavoori
# This script deletes the AMI and the snapshot created in earlier steps.
# Requirements : AWS CLI to be available in the path and credentials that can delete AMIs and snapshots
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

if [ "$#" -ne 1 ]; then
	LOG="============================================================="; write_log
	LOG="Illegal number of parameters. Script requires the name of the region"; write_log
  LOG="Usage: $0 <region-name>"; write_log
  LOG="============================================================="; write_log
  exit 1
fi

REGION=$1
APP_NAME="OpenVPN"

LOG="============================================================="; write_log
LOG="Finding the AMI ID that is created in previous steps.. in region $REGION" ; write_log
AMI_ID=$(aws --region $REGION ec2 describe-images --filters Name=state,Values=available Name=tag:image_app,Values=$APP_NAME --output text --query 'Images[*].ImageId')
if [[ $AMI_ID = *[!\ ]* ]];
then
      LOG="AMI with ID : $AMI_ID found tagged with $APP_NAME" ; write_log
      LOG="De-registring the AMI with AMI ID : $AMI_ID" ; write_log
      aws --region $REGION ec2 deregister-image --image-id $AMI_ID
else
      LOG="No AMIs found tagged with image_app $APP_NAME in region $REGION" ; write_log
fi

LOG="Finding the Snapshot ID that is created in previous steps.. in region $REGION" ; write_log
SNAP_ID=$(aws --region $REGION ec2 describe-snapshots --owner-ids self --filters Name=tag:image_app,Values=$APP_NAME --output text --query 'Snapshots[*].SnapshotId')
if [[ $SNAP_ID = *[!\ ]* ]];
then
      LOG="Snapshot with ID : $SNAP_ID found tagged with $APP_NAME" ; write_log
      LOG="Deleting the snapshot with Snapshot  ID : $SNAP_ID" ; write_log
      aws --region $REGION ec2 delete-snapshot --snapshot-id $SNAP_ID
else
      LOG="No Snapshots found tagged with image_app $APP_NAME in region $REGION" ; write_log
fi
LOG="Done with deleting the AMIs and Snapshots in region $REGION" ; write_log
LOG="============================================================="; write_log