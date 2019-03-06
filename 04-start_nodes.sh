#!/usr/bin/env bash

CONFIG=$(<configuration.json)

SG_NAME=`echo $CONFIG | jq '."security-group-name"' | tr -d '"'`
BUCKET_NAME=`echo $CONFIG | jq '."s3-bucket-name"' | tr -d '"'`
ROLE_NAME=`echo $CONFIG | jq '."role-name"' | tr -d '"'`
KEY_VALUE_PAIR=`echo $CONFIG | jq '."key-name"' | tr -d '"'`
SUBNET_ID=`echo $CONFIG | jq '."subnet-id"' | tr -d '"'`
AVAILABILITY_ZONE=`echo $CONFIG | jq '."availability-zone"' | tr -d '"'`
REGION=`echo $CONFIG | jq '."region"' | tr -d '"'`
MASTER_NODE_COUNT=`echo $CONFIG | jq '."master-node-count"' | tr -d '"'`
DATA_NODE_COUNT=`echo $CONFIG | jq '."data-node-count"' | tr -d '"'`
CLIENT_NODE_COUNT=`echo $CONFIG | jq '."client-node-count"' | tr -d '"'`
NAME=`echo $CONFIG | jq '."name"' | tr -d '"'`
IMAGE_NAME=`echo $CONFIG | jq '."target-image-name"' | tr -d '"'`
TAGS=`echo $CONFIG | jq '."tags"' | tr -d '"'`

sed  -e "s/my-region/${REGION}/g" -e "s/my-bucket/${BUCKET_NAME}/g" -e "s/my_cluster_name/${NAME}/g" ./04-runtime.data.userdata.txt | tee ./runtime.data.userdata.txt
sed  -e "s/my-region/${REGION}/g" -e "s/my-bucket/${BUCKET_NAME}/g" -e "s/my_cluster_name/${NAME}/g" ./04-runtime.master.userdata.txt | tee ./runtime.master.userdata.txt
sed  -e "s/my-region/${REGION}/g" -e "s/my-bucket/${BUCKET_NAME}/g" -e "s/my_cluster_name/${NAME}/g" ./04-runtime.client.userdata.txt | tee ./runtime.client.userdata.txt

SECURITY_GROUPS=`echo $(aws ec2 describe-security-groups --filters Name=group-name,Values=${SG_NAME})`

SECURITY_GROUP_ID=`echo $SECURITY_GROUPS | jq '.SecurityGroups[0].GroupId' | tr -d '"'`

AMIS=`echo $(aws ec2 describe-images --filters "Name=tag:Name,Values=${IMAGE_NAME}")`

BASE_IMAGE_ID=`echo $AMIS | jq '.Images[0].ImageId' | tr -d '"'`

echo "Using base id ${BASE_IMAGE_ID}"

INSTANCES=`echo $(aws ec2 run-instances --image-id ${BASE_IMAGE_ID} \
  --count ${MASTER_NODE_COUNT} \
  --instance-type t2.xlarge \
  --key-name ${KEY_VALUE_PAIR} \
  --subnet-id ${SUBNET_ID} \
  --iam-instance-profile Name=${ROLE_NAME} \
  --user-data file://runtime.master.userdata.txt \
  --tag-specifications="ResourceType=instance,Tags=[${TAGS},{Key=Name,Value=${NAME}-master}]" \
  --associate-public-ip-address \
  --security-group-ids ${SECURITY_GROUP_ID} | \
jq -rc '.Instances[].InstanceId')`

echo $INSTANCES

echo "Waiting for instances to run state"

aws ec2 wait instance-running --instance-ids $INSTANCES

echo "instances now running"

for instance in $INSTANCES; do
   VOLUMEDATA=$(aws ec2 describe-volumes --filters Name=tag:Name,Values=${NAME}-${COUNT}-master --query "Volumes[*].{ID:VolumeId,Tag:Tags}")

   if [ `echo $VOLUMEDATA | jq length` -eq 1 ]
   then
     VOLUMEID=`echo $VOLUMEDATA | jq .[].ID | tr -d '"'`
     echo "volume already exists!"
   else
     echo "Creating volume"
     VOLUMEID=`echo $(aws ec2 create-volume --availability-zone ${AVAILABILITY_ZONE} \
       --volume-type gp2 --size 128 \
       --tag-specifications "ResourceType=volume,Tags=[${TAGS},{Key=Name,Value=${NAME}-${COUNT}-master}]") | jq .VolumeId | tr -d '"'`

      aws ec2 wait volume-available --volume-ids $VOLUMEID

      echo "Volume created"
   fi

   aws ec2 attach-volume --device /dev/xvdba --instance-id $instance --volume-id $VOLUMEID

   aws ec2 modify-instance-attribute --instance-id $instance --block-device-mappings "[{\"DeviceName\": \"/dev/xvdba\",\"Ebs\":{\"DeleteOnTermination\":false}}]"

   COUNT=$((COUNT+1))
done

INSTANCES=`echo $(aws ec2 run-instances --image-id ${BASE_IMAGE_ID} \
  --count ${DATA_NODE_COUNT} \
  --instance-type t2.xlarge \
  --key-name ${KEY_VALUE_PAIR} \
  --subnet-id ${SUBNET_ID} \
  --iam-instance-profile Name=${ROLE_NAME} \
  --user-data file://runtime.data.userdata.txt \
  --tag-specifications="ResourceType=instance,Tags=[${TAGS},{Key=Name,Value=${NAME}-data}]" \
  --associate-public-ip-address \
  --security-group-ids ${SECURITY_GROUP_ID} | \
jq -rc '.Instances[].InstanceId')`

echo "Waiting for instances to run state"

aws ec2 wait instance-running --instance-ids $INSTANCES

echo "instances now running"

echo "Instance ids: ${INSTANCES}"

COUNT=1
for instance in $INSTANCES; do
   VOLUMEDATA=$(aws ec2 describe-volumes --filters Name=tag:Index,Values=${COUNT}-data --query "Volumes[*].{ID:VolumeId,Tag:Tags}")

   if [ `echo $VOLUMEDATA | jq length` -eq 1 ]
   then
     VOLUMEID=`echo $VOLUMEDATA | jq .[].ID | tr -d '"'`
     echo "volume already exists!"
   else
     echo "Creating volume"
     VOLUMEID=`echo $(aws ec2 create-volume --availability-zone ${AVAILABILITY_ZONE} \
       --volume-type gp2 --size 1024 \
       --tag-specifications "ResourceType=volume,Tags=[${TAGS},{Key=Index,Value=${COUNT}},{Key=Name,Value=${NAME}-${COUNT}-data}]") | jq .VolumeId | tr -d '"'`

      aws ec2 wait volume-available --volume-ids $VOLUMEID

      echo "Volume created"
   fi

   echo "instance id : ${instance} being attached to ${VOLUMEID}"
   aws ec2 attach-volume --device /dev/xvdba --instance-id ${instance} --volume-id ${VOLUMEID}

   aws ec2 modify-instance-attribute --instance-id $instance --block-device-mappings "[{\"DeviceName\": \"/dev/xvdba\",\"Ebs\":{\"DeleteOnTermination\":false}}]"

   COUNT=$((COUNT+1))
done