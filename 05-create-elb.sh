#!/usr/bin/env bash

CONFIG=$(<configuration.json)

SUBNET_ID=`echo $CONFIG | jq '."subnet-id"' | tr -d '"'`
SG_NAME=`echo $CONFIG | jq '."security-group-name-for-elb"' | tr -d '"'`
SECURITY_GROUPS=`echo $(aws ec2 describe-security-groups --filters Name=group-name,Values=${SG_NAME})`
VPC_ID=`echo $CONFIG | jq '."vpc-id"' | tr -d '"'`
MY_IP=`echo $(curl -s http://whatismyip.akamai.com/)`
NAME=`echo $CONFIG | jq '."name"' | tr -d '"'`

if [ `echo $SECURITY_GROUPS | jq '.SecurityGroups | length'` -eq 1 ]
then
  echo "Group exists...."

  SECURITY_GROUP_ID=`echo $SECURITY_GROUPS | jq '.SecurityGroups[0].GroupId' | tr -d '"'`
else
  echo "Group does not exist.. creating"

  TMP=`echo $(aws ec2 create-security-group --description '${SG_NAME}' --group-name=${SG_NAME} --vpc-id ${VPC_ID})`

  SECURITY_GROUP_ID=`echo $TMP | jq '.GroupId' | tr -d '"'`

  aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=5601,ToPort=5601,IpRanges="[{CidrIp=${MY_IP}/32,Description='node communication within the VPC'}]"

  echo "Group created"
fi

DNS=`echo $(aws elb create-load-balancer --load-balancer-name ${NAME} \
  --security-groups ${SECURITY_GROUP_ID} \
  --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=5601" \
  --subnets ${SUBNET_ID})`

IDS=`echo $(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=${NAME}-master" --query "Reservations[].Instances[].InstanceId" --output text)`

aws elb register-instances-with-load-balancer --load-balancer-name ${NAME} --instances ${IDS}

echo $DNS