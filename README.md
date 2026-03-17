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

AWS Replicator documentation:

- https://docs.localstack.cloud/aws/tooling/aws-replicator/

## Prerequisites

- A valid [LocalStack for AWS license](https://localstack.cloud/pricing), which provides a [`LOCALSTACK_AUTH_TOKEN`](https://docs.localstack.cloud/getting-started/auth-token/).
- LocalStack CLI v4.2.0 or higher.
- `awslocal` (`awscli-local`).
- Terraform CLI.
- Docker.
- Two configured AWS profiles:
- one for LocalStack access (default: `localstack` for Terraform and `local` in `cdk/Makefile`)
- one for AWS deployment (default: `ls-sandbox`)

```bash
export LOCALSTACK_AUTH_TOKEN=<your-auth-token>
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

## CDK Workflow

Run commands from `cdk/`.

1. Deploy platform resources to AWS:

```bash
make deploy-platform
```

2. Bootstrap CDK in LocalStack:

```bash
make bootstrap
```

3. Replicate VPC and subnet resources from the platform stack:

```bash
make replicate
```

4. Deploy the application stack to LocalStack:

```bash
make deploy-application
```

The `replicate_cdk.sh` script reads `PlatformStack` outputs, starts replicator jobs, and waits until replication is completed.

## LocalStack Management

Use the root `Makefile` for LocalStack lifecycle commands only. The Terraform and CDK directories keep their own deployment Makefiles.

## Cleanup

Terraform:

```bash
cd terraform
make destroy-application
make destroy-platform-aws
```

CDK:

```bash
cd cdk
make destroy-application
make destroy-platform
```
