AWS_PROFILE ?= ls-sandbox
LOCAL_AWS_PROFILE ?= localstack
AUTO_APPROVE ?= --auto-approve
LOCALSTACK_AUTH_TOKEN ?= 

deploy-platform-aws:
	cd platform; \
	terraform init; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform apply $(AUTO_APPROVE); \
	terraform output > ../application/terraform.tfvars

destroy-platform-aws:
	cd platform; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform destroy $(AUTO_APPROVE);

deploy-application:
	cd application; \
	TF_WORKSPACE=local TF_VAR_aws_profile=$(LOCAL_AWS_PROFILE) terraform apply $(AUTO_APPROVE);

destroy-application:
	cd application; \
	TF_WORKSPACE=local TF_VAR_aws_profile=$(LOCAL_AWS_PROFILE) terraform destroy $(AUTO_APPROVE);
