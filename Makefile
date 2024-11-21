AWS_PROFILE ?= ls-sandbox
LOCAL_AWS_PROFILE ?= local

deploy-platform:
	cd cdk/platform && \
		AWS_PROFILE=$(AWS_PROFILE) pnpm cdk deploy --require-approval never --outputs-file outputs.json

replicate:
	AWS_PROFILE=$(AWS_PROFILE) bash ./replicate_cdk.sh

deploy-application:
	cd cdk/application && \
		AWS_PROFILE=$(LOCAL_AWS_PROFILE) AWS_REGION=eu-central-1 AWS_DEFAULT_REGION=eu-central-1 pnpm cdklocal bootstrap && \
		AWS_PROFILE=$(LOCAL_AWS_PROFILE) AWS_REGION=eu-central-1 AWS_DEFAULT_REGION=eu-central-1 pnpm cdklocal deploy --require-approval never --parameters VpcId=$(shell cat cdk/platform/outputs.json | jq .PlatformStack.VpcId -r) --parameters Subnets=$(shell cat cdk/platform/outputs.json | jq .PlatformStack.VpcPrivateSubnet1Id -r)
