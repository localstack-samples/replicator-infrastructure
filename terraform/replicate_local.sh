#!/usr/bin/env bash
# Replicate the platform VPC and its private subnets into the default LocalStack
# account, reading them from the LocalStack account that `make deploy-platform-local`
# deployed them to. This is the same replication as `localstack replicator start`
# against AWS, but through the Replicator HTTP API, whose source_aws_config accepts an
# endpoint_url. No AWS account is needed.
set -euo pipefail

ENDPOINT=${ENDPOINT:-http://localhost.localstack.cloud:4566}
# The replication job runs inside the LocalStack container, so it reads the source from there
SOURCE_ENDPOINT=${SOURCE_ENDPOINT:-http://localhost:4566}
PLATFORM_ACCOUNT_ID=${PLATFORM_ACCOUNT_ID:-111111111111}
TARGET_ACCOUNT_ID=${TARGET_ACCOUNT_ID:-000000000000}
REGION=${AWS_DEFAULT_REGION:-us-east-1}
TFVARS=${TFVARS:-application/terraform.tfvars}
MAX_ATTEMPTS=${MAX_ATTEMPTS:-60}

vpc_id=$(sed -n 's/^vpc_id *= *"\(.*\)"/\1/p' "$TFVARS")
subnet_ids=$(grep -o 'subnet-[0-9a-f]*' "$TFVARS")
if [ -z "$vpc_id" ] || [ -z "$subnet_ids" ]; then
  echo "No vpc_id or private_subnets in $TFVARS. Run 'make deploy-platform-local' first."
  exit 1
fi

# replicate <resource type> <identifier>
replicate() {
  local payload job job_id state
  payload=$(jq -n --arg type "$1" --arg id "$2" --arg account "$PLATFORM_ACCOUNT_ID" \
    --arg target "$TARGET_ACCOUNT_ID" --arg region "$REGION" --arg endpoint "$SOURCE_ENDPOINT" '{
      replication_type: "SINGLE_RESOURCE",
      replication_job_config: {resource_type: $type, resource_identifier: $id},
      source_aws_config: {
        aws_access_key_id: $account, aws_secret_access_key: "test",
        region_name: $region, endpoint_url: $endpoint
      },
      target_aws_config: {aws_access_key_id: $target, aws_secret_access_key: "test", region_name: $region}
    }')
  job=$(curl -sf -X POST "$ENDPOINT/_localstack/replicator/jobs" -H 'Content-Type: application/json' -d "$payload")
  job_id=$(echo "$job" | jq -r .job_id)
  echo "Replicating $1 $2 (job $job_id)"
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    job=$(curl -sf "$ENDPOINT/_localstack/replicator/jobs/$job_id")
    state=$(echo "$job" | jq -r .state)
    case "$state" in
      SUCCEEDED) return 0 ;;
      ERROR) echo "Replication of $1 $2 failed: $job"; return 1 ;;
    esac
    sleep 2
  done
  echo "Replication of $1 $2 did not finish, last state: $state"
  return 1
}

replicate AWS::EC2::VPC "$vpc_id"
for subnet_id in $subnet_ids; do
  replicate AWS::EC2::Subnet "$subnet_id"
done
echo "Replicated VPC $vpc_id and subnets $(echo $subnet_ids)"
