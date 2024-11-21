AWS_PROFILE ?= ls-sandbox
LOCAL_AWS_PROFILE ?= local
AUTO_APPROVE ?= --auto-approve

deploy-platform:
	cd platform; \
	terraform init; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform apply $(AUTO_APPROVE); \
	terraform output > ../application/terraform.tfvars

deploy-application-aws:
	cd application; \
	terraform init; \
	TF_WORKSPACE=aws TF_VAR_aws_profile=$(AWS_PROFILE) terraform apply $(AUTO_APPROVE);

destroy-application-aws:
	cd application; \
	TF_WORKSPACE=aws TF_VAR_aws_profile=$(AWS_PROFILE) terraform destroy $(AUTO_APPROVE);

deploy-application:
	cd application; \
	tflocal init; \
	TF_WORKSPACE=local TF_VAR_aws_profile=$(LOCAL_AWS_PROFILE) tflocal apply $(AUTO_APPROVE);

destroy-application:
	cd application; \
	TF_WORKSPACE=local TF_VAR_aws_profile=$(LOCAL_AWS_PROFILE) tflocal destroy $(AUTO_APPROVE);

destroy-platform:
	cd platform; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform destroy $(AUTO_APPROVE);
