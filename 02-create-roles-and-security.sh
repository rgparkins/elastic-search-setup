#!/usr/bin/env bash

function usage() {
  echo "Usage:"
  echo "  create.sh <vpc_id> "
}

if [ $# -ne 1 ]
  then
    usage
    exit
fi

SG_NAME="elastic-search-test"
BUCKET_NAME="elastic-data"
ROLE_NAME="elastic-search-role-test"
VPC_ID=$1
MY_IP=`echo $(curl -s http://whatismyip.akamai.com/)`

VPC_IP=`echo $(aws ec2 describe-vpcs --vpc-ids ${VPC_ID} | jq '.Vpcs[0].CidrBlockAssociationSet[0].CidrBlock') | tr -d '"'`

echo "VPC internal id: ${VPC_IP}"
echo "Your external IP address : ${MY_IP}"

echo "*************** CREATING SECURITY GROUP ***************"

SECURITY_GROUPS=`echo $(aws ec2 describe-security-groups --filters Name=group-name,Values=${SG_NAME})`

if [ `echo $SECURITY_GROUPS | jq '.SecurityGroups | length'` -eq 1 ]
then
  echo "Group exists...."

  SECURITY_GROUP_ID=`echo $SECURITYGROUP | jq '.SecurityGroups[0].GroupId' | tr -d '"'`
else
  echo "Group does not exist.. creating"

  TMP=`echo $(aws ec2 create-security-group --description 'elastic search development' --group-name=${SG_NAME} --vpc-id ${VPC_ID})`

  SECURITY_GROUP_ID=`echo $TMP | jq '.GroupId' | tr -d '"'`

  aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges="[{CidrIp=${MY_IP}/32,Description='SSH access from my external IP'}]"
  aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=5601,ToPort=5601,IpRanges="[{CidrIp=${MY_IP}/32,Description='kibana access'}]"
  aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=9300,ToPort=9300,IpRanges="[{CidrIp=${VPC_IP},Description='node communication within the VPC'}]"

  echo "Group created"
fi

echo "Using security group: ${SECURITY_GROUP_ID}";
echo "********** FINISHED CREATING SECURITY GROUP ***********"

echo "*************** CREATING IAM ROLE ***************"

ROLES=`echo $(aws iam list-roles --path-prefix /elasticsearch)`

if [ `echo ${ROLES} | jq '.Roles | length'` -eq 1 ]
then
  echo "Role exists...."
else
  echo "Role does not exist. Creating...."

  TMP=`echo $(aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document file://02-trust-policy.json --path /elasticsearch/)`

  ROLE_ID=`echo ${TMP} | jq '.Role.RoleId' | tr -d '"'`

  sed  "s/my-bucket/${BUCKET_NAME}/g" ./02-policy-template.json | tee ./policy.json

  POLICY1=`echo $(aws iam create-policy --policy-name "elastic-search-policy-test" --policy-document file://policy.json --description "elasticsearch access to s3 and instance descriptions")`

  BUCKET_POLICY_ARN=`echo ${POLICY1} | jq '.Policy.Arn' | tr -d '"'`

  echo "Bucket policy: $BUCKET_POLICY_ARN"

  aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $BUCKET_POLICY_ARN

  echo "Role created"
fi

echo "********** FINISHED CREATING ROLE ***********"