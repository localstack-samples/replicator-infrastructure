#!/usr/bin/env bash

set -euo pipefail

PLATFORM_TF_DIR=${PLATFORM_TF_DIR:-platform}


log() {
    echo -n "$1" >&1
    echo
}

instruction() {
    printf "\033[0;32m"
    log "$1"
    printf "\033[0m"
}

replicate() {
    replicationResult=$(python -m localstack.pro.core.replicator start --replication-type SINGLE_RESOURCE --resource-arn $1 | sed -E 's/Replication request successful: //')
    echo $replicationResult | jq .job_id -r
}

wait_for_job() {
    python -m localstack.pro.core.replicator state --follow $1
}

instruction "Getting account id and region"
region=$(aws configure get region)
accountId=$(aws sts get-caller-identity --query Account --output text)
log "Account $accountId region $region"

instruction "Selecting VPC"
log "Fetching default VPC information from terraform"
vpcId=$(terraform -chdir="$PLATFORM_TF_DIR" output vpc_id | tr -d '"')
log "Found vpc: $vpcId"

instruction "Selecting Subnets"
log "Determining private subnets from terraform"
subnetIds=$(terraform -chdir="$PLATFORM_TF_DIR" output private_subnets | tr -d '"[] \n')
log "Found subnets: $subnetIds"

instruction "Replicating VPC"
vpcArn="arn:aws:ec2:$region:$accountId:vpc/$vpcId"
jobId=$(replicate $vpcArn)
instruction "Waiting for job $jobId completion"
wait_for_job $jobId

instruction "Replicating subnets"
jobIds=""
for subnet in ${subnetIds//,/ }
do
    log "Replication Subnet: $subnet"
    subnetArn="arn:aws:ec2:$region:$accountId:subnet/$subnet"
    jobId=$(replicate $subnetArn)
    log "started job $jobId"
    jobIds+="${jobId},"
done

for jobId in ${jobIds//,/ }
do
    instruction "Waiting for job $jobId completion"
    wait_for_job $jobId
done
