#!/usr/bin/env bash

CONFIG=$(<configuration.json)

SUBNET_ID=`echo $CONFIG | jq '."subnet-id"' | tr -d '"'`
SG_NAME=`echo $CONFIG | jq '."security-group-name-for-elb"' | tr -d '"'`
SECURITY_GROUPS=`echo $(aws ec2 describe-security-groups --filters Name=group-name,Values=${SG_NAME})`
VPC_ID=`echo $CONFIG | jq '."vpc-id"' | tr -d '"'`
MY_IP=`echo $(curl -s http://whatismyip.akamai.com/)`
NAME=`echo $CONFIG | jq '."name"' | tr -d '"'`
ELB=`aws elb describe-load-balancers --load-balancer-names "quoting-elasticsearch-nonprod"`

ELBDNSNAME=`echo $ELB | jq '.LoadBalancerDescriptions[0].CanonicalHostedZoneName' | tr -d '"'`
HOSTEDZONEID=`echo $CONFIG | jq '."hosted-zone-id"' | tr -d '"'`
DNS=`echo $CONFIG | jq '."dns"' | tr -d '"'`

echo $DNSNAME
echo $DNS

sed  -e "s/DNS/${DNS}/g" -e "s/ELB/${ELBDNSNAME}/g" ./06-change_record_set.json | tee ./change_record_set.json

aws route53 change-resource-record-sets --hosted-zone-id "${HOSTEDZONEID}" --cgit ststhange-batch "file://change_record_set.json"