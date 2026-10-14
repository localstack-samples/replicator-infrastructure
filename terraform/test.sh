#!/usr/bin/env bash
# Check that the replicated network matches the platform account, and that the
# application deployed into it answers through each entry point:
# 1. the VPC and private subnets exist in the application account with the same IDs and CIDRs
# 2. the ECS service runs its task
# 3. the internal ALB returns the app's response
# 4. the HTTP API, through its VPC link to the ALB, returns the app's response
# 5. the REST API sends a posted event to the SQS queue
set -euo pipefail

ENDPOINT=${ENDPOINT:-http://localhost.localstack.cloud:4566}
PLATFORM_ACCOUNT_ID=${PLATFORM_ACCOUNT_ID:-111111111111}
REGION=${AWS_DEFAULT_REGION:-us-east-1}
TFVARS=${TFVARS:-application/terraform.tfvars}
MAX_ATTEMPTS=${MAX_ATTEMPTS:-60}
EXPECTED_MESSAGE="I am running in a replicated environment"

# AWS CLI against LocalStack as the application account (000000000000) or the platform account
aws_app() { AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=$REGION aws --endpoint-url "$ENDPOINT" "$@"; }
aws_platform() { AWS_ACCESS_KEY_ID=$PLATFORM_ACCOUNT_ID AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=$REGION aws --endpoint-url "$ENDPOINT" "$@"; }

vpc_id=$(sed -n 's/^vpc_id *= *"\(.*\)"/\1/p' "$TFVARS")
subnet_ids=$(grep -o 'subnet-[0-9a-f]*' "$TFVARS")

for account in app platform; do
  eval "${account}_vpc=\$(aws_$account ec2 describe-vpcs --vpc-ids $vpc_id --query 'Vpcs[0].CidrBlock' --output text)"
  eval "${account}_subnets=\$(aws_$account ec2 describe-subnets --subnet-ids $(echo $subnet_ids) \
    --query 'sort_by(Subnets, &SubnetId)[].[SubnetId, VpcId, CidrBlock, AvailabilityZone]' --output text)"
done
if [ "$app_vpc" != "$platform_vpc" ] || [ "$app_subnets" != "$platform_subnets" ]; then
  echo "Test failed: the replicated network differs from the platform account"
  echo "platform: $platform_vpc"; echo "$platform_subnets"
  echo "application: $app_vpc"; echo "$app_subnets"
  exit 1
fi
echo "PASS: VPC $vpc_id ($app_vpc) and $(echo "$subnet_ids" | wc -l | tr -d ' ') subnets match the platform account"

running=0
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  running=$(aws_app ecs describe-services --cluster ecs-application --services application-services \
    --query 'services[0].runningCount' --output text)
  [ "$running" != "None" ] && [ "$running" -ge 1 ] && break
  echo "Attempt $attempt/$MAX_ATTEMPTS: ECS service has $running running tasks"
  sleep 5
done
if [ "$running" = "None" ] || [ "$running" -lt 1 ]; then
  echo "Test failed: the ECS service has no running task"
  exit 1
fi
echo "PASS: ECS service runs $running task(s)"

# expect_app <description> <url>
expect_app() {
  local body=""
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    body=$(curl -s -m 10 "$2" || true)
    if echo "$body" | jq -e --arg m "$EXPECTED_MESSAGE" '.status == "ok" and .message == $m' > /dev/null 2>&1; then
      echo "PASS: $1 returned the app's response"
      return 0
    fi
    echo "Attempt $attempt/$MAX_ATTEMPTS: $1 returned '$body'"
    sleep 5
  done
  echo "Test failed: $1 at $2 never returned the app's response"
  exit 1
}

alb_dns=$(aws_app elbv2 describe-load-balancers --names ecs-application --query 'LoadBalancers[0].DNSName' --output text)
expect_app "the ALB" "http://$alb_dns:4566/"

http_api_id=$(aws_app apigatewayv2 get-apis --query "Items[?Name=='ecs-application'].ApiId | [0]" --output text)
expect_app "the HTTP API" "http://$http_api_id.execute-api.localhost.localstack.cloud:4566/status"

rest_api_id=$(aws_app apigateway get-rest-apis --query "items[?name=='exemption-events-api'].id | [0]" --output text)
marker="ci-$(date +%s)-$RANDOM"
status=$(curl -s -m 30 -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  -d "{\"exemption\": \"$marker\"}" "http://$rest_api_id.execute-api.localhost.localstack.cloud:4566/local/v1/events")
if [ "$status" != "200" ]; then
  echo "Test failed: posting an event returned HTTP $status"
  exit 1
fi
queue_url=$(aws_app sqs get-queue-url --queue-name my-queue --query QueueUrl --output text)
received=""
for attempt in $(seq 1 10); do
  received=$(aws_app sqs receive-message --queue-url "$queue_url" --max-number-of-messages 10 \
    --wait-time-seconds 2 --query 'Messages[].Body' --output text)
  [[ "$received" == *"$marker"* ]] && break
done
if [[ "$received" != *"$marker"* ]]; then
  echo "Test failed: the event posted to the REST API did not reach my-queue"
  exit 1
fi
echo "PASS: the REST API sent the posted event to my-queue"

echo "Test passed: the application runs on the replicated network"
