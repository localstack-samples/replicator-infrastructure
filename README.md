## Requirements

localstack cli v4.2.0 or higher

`LOCALSTACK_AUTH_TOKEN` configured in environment

2 configured aws profiles

-   one to reach localstack (defaults to `localstack`)

-   one to create the resources in aws (defaults to `ls-sandbox`)

## Replicating with Terraform

From the `./terraform` folder run the following commands.

Deploy the infrastructure to AWS

`make deploy-platform-aws`

Attempt to deploy your application to localstack.

`make deploy-application`

It will fail with the following message.

```
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

The terraform configuration requires a specific vpc with the id shown in the error message to successfully deploy. The replicator can be used to replicate those resources while keeping their id.

```bash
AWS_PROFILE=ls-sandbox localstack replicator start --resource-identifier <vpc-id> --resource-type AWS::EC2::VPC
```

Once the vpc is replicated, we can replicate the subnet

```bash
AWS_PROFILE=ls-sandbox localstack replicator start --resource-identifier <subnet-id> --resource-type AWS::EC2::Subnet
```


## Clean up

```bash
make destroy-platform-aws
```