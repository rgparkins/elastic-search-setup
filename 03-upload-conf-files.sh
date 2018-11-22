#!/usr/bin/env bash

CONFIG=$(<configuration.json)

BUCKET_NAME=`echo ${CONFIG} | jq '."s3-bucket-name"' | tr -d '"'`
REGION=`echo ${CONFIG} | jq '."region"' | tr -d '"'`

sed  "s/my-region/${REGION}/g" ./03-elasticsearch_data.yml | tee ./elasticsearch_data.yml
sed  "s/my-region/${REGION}/g" ./03-elasticsearch_master.yml | tee ./elasticsearch_master.yml
sed  "s/my-region/${REGION}/g" ./03-elasticsearch_client.yml | tee ./elasticsearch_client.yml
sed  "s/my-region/${REGION}/g" ./03-Dockerfile | tee ./Dockerfile

echo "Pushing up common files"
aws s3 cp ./Dockerfile s3://${BUCKET_NAME}/elasticsearch/Dockerfile --region ${REGION}

echo "Pushing up the data node configuration files"

aws s3 cp ./elasticsearch_data.yml s3://${BUCKET_NAME}/elasticsearch/elasticsearch_data.yml --region ${REGION}
aws s3 cp ./03-data.jvm.options s3://${BUCKET_NAME}/elasticsearch/data.jvm.options --region ${REGION}
aws s3 cp ./03-docker-compose.data.yml s3://${BUCKET_NAME}/elasticsearch/docker-compose.data.yml --region ${REGION}

aws s3 cp ./elasticsearch_master.yml s3://${BUCKET_NAME}/elasticsearch/elasticsearch_master.yml --region ${REGION}
aws s3 cp ./03-master.jvm.options s3://${BUCKET_NAME}/elasticsearch/master.jvm.options --region ${REGION}
aws s3 cp ./03-docker-compose.master.yml s3://${BUCKET_NAME}/elasticsearch/docker-compose.master.yml --region ${REGION}

aws s3 cp ./elasticsearch_client.yml s3://${BUCKET_NAME}/elasticsearch/elasticsearch_client.yml --region ${REGION}
aws s3 cp ./03-client.jvm.options s3://${BUCKET_NAME}/elasticsearch/client.jvm.options --region ${REGION}
aws s3 cp ./03-docker-compose.client.yml s3://${BUCKET_NAME}/elasticsearch/docker-compose.client.yml --region ${REGION}

echo "Files copied"