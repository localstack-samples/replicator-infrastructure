# AWS Replicator Infrastructure Demo

| Key | Value |
| --- | --- |
| Environment | LocalStack and AWS |
| Services | VPC, Subnet, ALB, ECS Fargate, API Gateway, ECR, SQS |
| Integrations | Terraform and AWS CDK |
| Categories | AWS Replication | 
| Level | Beginner |
| GitHub | https://github.com/localstack-samples/replicator-infrastructure |

## Introduction

This repository demonstrates an infrastructure migration workflow where a platform VPC is created in AWS, then selected resources are replicated into LocalStack so an application stack can be deployed locally with the same VPC/Subnet IDs.

The sample includes two variants:

- `terraform/`: platform and application stacks with Terraform
- `cdk/`: platform and application stacks with AWS CDK

This sample application uses LocalStack's [AWS Replicator](https://docs.localstack.cloud/aws/tooling/aws-replicator/) feature.

## Prerequisites

- A valid [LocalStack for AWS license](https://localstack.cloud/pricing), which provides a [`LOCALSTACK_AUTH_TOKEN`](https://docs.localstack.cloud/aws/getting-started/auth-token/).
- LocalStack CLI v4.2.0 or higher (needed for `localstack replicator`, which has no `lstk` equivalent).
- [`lstk` CLI](https://docs.localstack.cloud/aws/developer-tools/running-localstack/lstk/), installed via `npm install -g @localstack/lstk` or `brew install localstack/tap/lstk`.
- AWS CLI, required by `lstk aws`.
- Terraform CLI.
- Docker.
- Two configured AWS profiles:
  - one for LocalStack access (default: `localstack` for Terraform, created by `lstk setup aws`, and `local` in `cdk/Makefile`)
  - one for AWS deployment (default: `ls-sandbox`)

To start LocalStack, run the following:

```bash
export LOCALSTACK_AUTH_TOKEN=<your-auth-token>
make start
```

## Terraform Workflow

Run commands from `terraform/`.

1. Deploy the platform infrastructure to AWS:

```bash
make deploy-platform-aws
```

2. Attempt to deploy the application to LocalStack:

```bash
make deploy-application
```

3. The first deploy is expected to fail with output like:

```text
│ Error: creating ELBv2 application Load Balancer (ecs-application): operation error Elastic Load Balancing v2: CreateLoadBalancer, https response error StatusCode: 400, RequestID: aa6de73e-90a4-4a8a-84f4-3714a21a2fdb, api error InvalidSubnetID.NotFound: The subnet ID '<subnet-id>' does not exist
│
│   with module.alb.aws_lb.this[0],
│   on .terraform/modules/alb/main.tf line 12, in resource "aws_lb" "this":
│   12: resource "aws_lb" "this" {
│
╵
╷
│ Error: creating ELBv2 Target Group (tf-20250310185220542800000003): operation error Elastic Load Balancing v2: CreateTargetGroup, https response error StatusCode: 400, RequestID: 7d545ebb-b230-4530-8d85-be79fcc7b1c2, api error ValidationError: The VPC ID '<vpc-id>' is not found
│
│   with module.alb.aws_lb_target_group.this["ex_ecs"],
│   on .terraform/modules/alb/main.tf line 487, in resource "aws_lb_target_group" "this":
│  487: resource "aws_lb_target_group" "this" {
```

4. Replicate the missing VPC and subnet IDs reported in the error:

```bash
AWS_PROFILE=ls-sandbox localstack replicator start --resource-identifier <vpc-id> --resource-type AWS::EC2::VPC
AWS_PROFILE=ls-sandbox localstack replicator start --resource-identifier <subnet-id> --resource-type AWS::EC2::Subnet
```

5. Re-run the application deployment:

```bash
make deploy-application
```

### Without an AWS account

You can run the same workflow with a second LocalStack account standing in for the AWS account that owns the platform. The platform goes to account `111111111111` (set `PLATFORM_ACCOUNT_ID` to change it), and the Replicator copies the VPC and subnets from there into the default account `000000000000`, where the application is deployed.

```bash
make deploy-platform-local   # deploy the VPC into account 111111111111
make deploy-application      # fails: the VPC and subnets are not in account 000000000000 yet
make replicate-local         # replicate the VPC and private subnets into account 000000000000
make deploy-application      # succeeds
make test
```

`make replicate-local` runs `replicate_local.sh`, which calls the [Replicator HTTP API](https://docs.localstack.cloud/aws/developer-tools/aws-replicator/#using-the-http-api) with `source_aws_config.endpoint_url` pointing at LocalStack, because `localstack replicator start` always reads from AWS.

### Test the deployment

`make test` checks that:

- the VPC and private subnets in the application account have the same IDs, CIDRs and availability zones as in the platform account
- the ECS service runs its task
- the internal ALB and the HTTP API, through its VPC link, return the application's response
- an event posted to the REST API reaches the `my-queue` SQS queue

The network check compares against the platform account in LocalStack, so `make test` belongs to the workflow without an AWS account. CI runs that workflow on every pull request.

## CDK Workflow

Run commands from the repository root with `make -f cdk/Makefile <target>`, since the targets use paths such as `cdk/platform` and `./replicate_cdk.sh`.

1. Deploy platform resources to AWS:

```bash
make -f cdk/Makefile deploy-platform
```

2. Bootstrap CDK in LocalStack:

```bash
make -f cdk/Makefile bootstrap
```

3. Replicate VPC and subnet resources from the platform stack:

```bash
make -f cdk/Makefile replicate
```

4. Deploy the application stack to LocalStack:

```bash
make -f cdk/Makefile deploy-application
```

The `replicate_cdk.sh` script reads `PlatformStack` outputs, starts replicator jobs, and waits until replication is completed.

## Cleanup

### Terraform

```bash
cd terraform
make destroy-application
make destroy-platform-aws    # or make destroy-platform-local
```

### CDK

```bash
make -f cdk/Makefile destroy-application
make -f cdk/Makefile destroy-platform
```

## License

Licensed under Apache License 2.0. See [LICENSE](LICENSE).
