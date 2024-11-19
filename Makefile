AWS_PROFILE ?= ls-sandbox

deploy-platform:
	cd platform; \
	terraform init; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform apply;

deploy-application:
	cd application; \
	terraform init; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform apply;

destroy-application:
	cd application; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform destroy;

destroy-platform:
	cd platform; \
	TF_VAR_aws_profile=$(AWS_PROFILE) terraform destroy;
