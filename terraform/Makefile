AWS_PROFILE ?= ls-sandbox
LOCAL_AWS_PROFILE ?= localstack
AUTO_APPROVE ?= --auto-approve
LOCALSTACK_AUTH_TOKEN ?=
# LocalStack account that stands in for the AWS platform account when you have no AWS account
PLATFORM_ACCOUNT_ID ?= 111111111111

deploy-platform-aws:
	cd platform; \
	terraform init; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform apply $(AUTO_APPROVE); \
	terraform output > ../application/terraform.tfvars

destroy-platform-aws:
	cd platform; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform destroy $(AUTO_APPROVE);

deploy-platform-local: ## Deploy the platform into a second LocalStack account instead of AWS
	cd platform && \
	lstk tf --account $(PLATFORM_ACCOUNT_ID) init -input=false && \
	terraform workspace select -or-create local && \
	TF_VAR_aws_profile=$(LOCAL_AWS_PROFILE) lstk tf --account $(PLATFORM_ACCOUNT_ID) apply $(AUTO_APPROVE) && \
	terraform output > ../application/terraform.tfvars

destroy-platform-local:
	cd platform && \
	terraform workspace select local && \
	TF_VAR_aws_profile=$(LOCAL_AWS_PROFILE) lstk tf --account $(PLATFORM_ACCOUNT_ID) destroy $(AUTO_APPROVE)

replicate-local: ## Replicate the platform VPC and subnets from the second LocalStack account
	PLATFORM_ACCOUNT_ID=$(PLATFORM_ACCOUNT_ID) ./replicate_local.sh

deploy-application:
	cd application && \
	lstk tf init -input=false && \
	terraform workspace select -or-create local && \
	TF_VAR_aws_profile=$(LOCAL_AWS_PROFILE) lstk tf apply $(AUTO_APPROVE)

destroy-application:
	cd application && \
	terraform workspace select local && \
	TF_VAR_aws_profile=$(LOCAL_AWS_PROFILE) lstk tf destroy $(AUTO_APPROVE)

test: ## Check the replicated network and the deployed application
	PLATFORM_ACCOUNT_ID=$(PLATFORM_ACCOUNT_ID) ./test.sh

.PHONY: deploy-platform-aws destroy-platform-aws deploy-platform-local destroy-platform-local replicate-local deploy-application destroy-application test
