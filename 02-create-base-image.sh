#!/usr/bin/env bash

function usage() {
  echo "Usage:"
  echo "  02-create-base-image.sh <subnet_id> "
}

if [ $# -ne 1 ]
  then
    usage
    exit
fi

CURRENT_UBUNTU_IMAGE=ami-0ac019f4fcb7cb7e6
ROLE_NAME="elastic-search-role-test"
KEY_VALUE_PAIR="elastic-dev-test"
SUBNET_ID=$1
IMAGE_NAME=elasticsearch-image-test

KVPAIRS=`echo $( aws ec2 describe-key-pairs --filters Name=key-name,Values=${KEY_VALUE_PAIR})`

if [ `echo $KVPAIRS | jq '.KeyPairs | length'` -eq 1 ]
then
  echo "Key already exists."
else
  echo "Creating pem key"
  aws ec2 create-key-pair --key-name $KEY_VALUE_PAIR | jq -r ".KeyMaterial" > ./${KEY_VALUE_PAIR}.pem

  echo "Your pem key for ssh'ing into your instance has been created. $KEY_VALUE_PAIR.pem"
  exit;
fi

SECURITY_GROUPS=`echo $(aws ec2 describe-security-groups --filters Name=group-name,Values=${SG_NAME})`

SECURITY_GROUP_ID=`echo $SECURITYGROUP | jq '.SecurityGroups[0].GroupId' | tr -d '"'`

INSTANCES=`echo $(aws ec2 run-instances --image-id ${CURRENT_UBUNTU_IMAGE} \
  --count 1 \
  --instance-type t2.medium \
  --key-name ${KEY_VALUE_PAIR} \
  --subnet-id ${SUBNET_ID} \
  --iam-instance-profile Name=${ROLE_NAME} \
  --user-data file://02-image-userdata.txt \
  --tag-specifications="ResourceType=instance,Tags=[{Key=Name,Value=es-baseimage-test}]" \
  --associate-public-ip-address \
  --security-group-ids ${SECURITY_GROUP_ID} | \
jq -rc '.Instances[].InstanceId')`

echo "waiting for instances to run"

aws ec2 wait instance-running --instance-ids $INSTANCES

echo "instances running"

echo "creating image called ${IMAGE_NAME}"

aws ec2 create-image --instance-id $INSTANCES --name $IMAGE_NAME

echo "image created"
