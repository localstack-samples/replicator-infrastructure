#!/usr/bin/env bash

set -euo pipefail

log() {
    echo -n "$1" >&1
    echo
}

instruction() {
    printf "\033[0;32m"
    log "$1"
    printf "\033[0m"
}

instruction "Getting account id and region"
region=$(aws configure get region)
accountId=$(aws sts get-caller-identity --query Account --output text)
log "Account $accountId region $region"

instruction "Fetching default VPC information"
vpc=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query Vpcs[0])
vpcId=$(echo $vpc | jq ".VpcId" -r)
log "Found vpc: $vpcId"

instruction "Determining private subnets"
subnetsRaw=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpcId --query Subnets[].SubnetArn --output text | sed -E 's/\s+/ /g')
subnetsConcat=$(echo $subnetsRaw | sed -E 's/\s+/,/g')
log "Found subnets: $subnetsConcat"
# TODO: filter by private subnets only

instruction "Replicating VPC"
vpcArn="arn:aws:ec2:$region:$accountId:vpc/$vpcId"
replicationResult=$(python -m localstack.pro.core.replicator start --replication-type SINGLE_RESOURCE --resource-arn $vpcArn | sed -E 's/Replication request successful: //')
jobId=$(echo $replicationResult | jq .job_id -r)
log "Job id: $jobId"

instruction "Waiting for job completion"
python -m localstack.pro.core.replicator state --follow $jobId
