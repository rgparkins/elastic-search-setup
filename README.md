# elastic-search-setup
Scripts to install and run an elastic search cluster with kibana

# setup

1. `aws cli` installed
2. `jq` installed

At time of writing there is no single script that will run the whole setup BUT you can run each of the scripts in order at 
which point you should be able to access you elastic search kibana data on port 5601 from the master node

The scripts rely on a central configuration.json file that holds the data the scripts will use. An example of the script is below

# requirements

1. A VPC on amazon
2. A subnet under that VPC
3. An S3 bucket

The configuration file that needs to be updated is described below
```
{
  "vpc-id": "vpc-xxxxx",                              # The VPC id that you wish the cluster to be deployed to
  "region": "us-east-1",                              # The region of the cluster
  "availability-zone": "us-east-1a",                  # The availability zone 
  "security-group-name":"elastic-search-test",        # The name you want for your security group
  "subnet-id": "subnet-xxxx",                         # The subnet id 
  "base-ami": "ami-xxxx",                             # The Amazon base AMI (Can be found in the console, I use ubuntu)
  "role-name": "elastic-search-role-test",            # The name you want your IAM Role to be
  "key-name": "elastic-dev-test",                     # The name of your PEM key that will be downloaded for accessing the instance
  "s3-bucket-name": "xxxx",                           # The name of your S3 bucket (you will have to have this created)
  "target-image-name": "elasticsearch-image-test",    # The name you want for your image that all instances will be created from
  "data-node-count": 2,                               # The number of data nodes
  "master-node-count": 1,                             # The number of master nodes
  "name": "elasticsearch-test"                        # The name of your cluster
}
```

# To do's

1. Use directories to tidy up
2. Check if the volume setup is correct for elastic search
3. Can kibana run on all master nodes?
4. Multiple regions?
5. Route 53 dns creation to master nodes
6. If more than 1 master node we need an ELB 
7. nginx
