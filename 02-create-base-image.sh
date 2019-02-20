#!/usr/bin/env bash

CONFIG=$(<configuration.json)

SG_NAME=`echo $CONFIG | jq '."security-group-name"' | tr -d '"'`
CURRENT_UBUNTU_IMAGE=`echo $CONFIG | jq '."base-ami"' | tr -d '"'`
ROLE_NAME=`echo $CONFIG | jq '."role-name"' | tr -d '"'`
KEY_VALUE_PAIR=`echo $CONFIG | jq '."key-name"' | tr -d '"'`
SUBNET_ID=`echo $CONFIG | jq '."subnet-id"' | tr -d '"'`
IMAGE_NAME=`echo $CONFIG | jq '."target-image-name"' | tr -d '"'`

KVPAIRS=`echo $( aws ec2 describe-key-pairs --filters Name=key-name,Values=${KEY_VALUE_PAIR})`

if [ `echo ${KVPAIRS} | jq '.KeyPairs | length'` -eq 1 ]
then
  echo "Key already exists."
else
  echo "Creating pem key"
  aws ec2 create-key-pair --key-name ${KEY_VALUE_PAIR} | jq -r ".KeyMaterial" > ./${KEY_VALUE_PAIR}.pem

  echo "Your pem key for ssh'ing into your instance has been created. $KEY_VALUE_PAIR.pem"
fi

SECURITY_GROUPS=`echo $(aws ec2 describe-security-groups --filters Name=group-name,Values=${SG_NAME})`

SECURITY_GROUP_ID=`echo ${SECURITY_GROUPS} | jq '.SecurityGroups[0].GroupId' | tr -d '"'`

echo "Creating instance from which the base image will be made"
INSTANCES=`echo $(aws ec2 run-instances --image-id ${CURRENT_UBUNTU_IMAGE} \
  --count 1 \
  --instance-type t2.medium \
  --key-name ${KEY_VALUE_PAIR} \
  --subnet-id ${SUBNET_ID} \
  --iam-instance-profile Name=${ROLE_NAME} \
  --user-data file://02-image-userdata.txt \
  --tag-specifications="ResourceType=instance,Tags=[{Key=Name,Value=${IMAGE_NAME}}]" \
  --associate-public-ip-address \
  --security-group-ids ${SECURITY_GROUP_ID} | \
jq -rc '.Instances[].InstanceId')`

echo "waiting for instance to be ok"

aws ec2 wait instance-status-ok --instance-ids $INSTANCES

echo "instances ok"

echo "creating image called ${IMAGE_NAME}"

IMAGE_ID=`echo $(aws ec2 create-image --instance-id ${INSTANCES} --name ${IMAGE_NAME} --description "AN AMI for elasticsearch")`

IM=`echo ${IMAGE_ID} | jq '.ImageId' | tr -d '"'`

aws ec2 create-tags --resources ${IM} --tags Key=Name,Value=${IMAGE_NAME}
echo "image created"