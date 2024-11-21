#!/usr/bin/env bash

set -euo pipefail

TARGET_AWS_PROFILE=${TARGET_AWS_PROFILE:-ls-sandbox}
TARGET_LOCALSTACK_PROFILE=${TARGET_AWS_PROFILE:-local}
PLATFORM_STACK_NAME=${PLATFORM_STACK_NAME:-PlatformStack}

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
    replicationResult=$(AWS_PROFILE=$TARGET_AWS_PROFILE python -m localstack.pro.core.replicator start --replication-type SINGLE_RESOURCE --resource-arn $1 | sed -E 's/Replication request successful: //')
    echo $replicationResult | jq .job_id -r
}

wait_for_job() {
    python -m localstack.pro.core.replicator state --follow $1
}

instruction "Restarting Localstack"
ls-restart

instruction "Getting account id and region"
region=$(aws configure get region)
accountId=$(aws sts get-caller-identity --query Account --output text)
log "Account $accountId region $region"

instruction "Fetching VPC information"
stackOutputs=$(AWS_PROFILE=$TARGET_AWS_PROFILE aws cloudformation describe-stacks --stack-name $PLATFORM_STACK_NAME --query Stacks[0].Outputs)
vpcId=$(echo $stackOutputs | jq '. | map(select(.OutputKey == "VpcId")) | .[0].OutputValue' -r)
subnetIds=$(echo $stackOutputs | jq '. | map(select(.OutputKey == "VpcPrivateSubnet1Id")) | .[0].OutputValue' -r)
log "Vpc id $vpcId, subnets $subnetIds"

instruction "Replicating VPC"
vpcArn="arn:aws:ec2:$region:$accountId:vpc/$vpcId"
jobId=$(replicate $vpcArn)
log "Job id: $jobId"

instruction "Waiting for job completion"
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
