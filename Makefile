AWS_PROFILE ?= ls-sandbox
LOCAL_AWS_PROFILE ?= local
DEPLOY_REGION ?= eu-central-1

deploy-platform:
	cd cdk/platform && \
		AWS_PROFILE=$(AWS_PROFILE) pnpm cdk deploy --require-approval never --outputs-file outputs.json

replicate:
	AWS_PROFILE=$(AWS_PROFILE) bash ./replicate_cdk.sh

deploy-application:
	cd cdk/application && \
		AWS_PROFILE=$(LOCAL_AWS_PROFILE) AWS_REGION=$(DEPLOY_REGION) AWS_DEFAULT_REGION=$(DEPLOY_REGION) pnpm cdklocal bootstrap && \
		AWS_PROFILE=$(LOCAL_AWS_PROFILE) AWS_REGION=$(DEPLOY_REGION) AWS_DEFAULT_REGION=$(DEPLOY_REGION) pnpm cdklocal deploy --require-approval never --parameters VpcId=$(shell cat cdk/platform/outputs.json | jq .PlatformStack.VpcId -r) --parameters Subnets=$(shell cat cdk/platform/outputs.json | jq .PlatformStack.VpcPrivateSubnet1Id -r)
