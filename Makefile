export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION ?= us-east-1

.DEFAULT_GOAL := usage

usage: ## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\$$//' | sed -e 's/##//'

check: ## Check if required prerequisites are installed
	@command -v docker > /dev/null 2>&1 || { echo "Docker is not installed. Please install Docker and try again."; exit 1; }
	@command -v python3 > /dev/null 2>&1 || { echo "Python 3 is not installed. Please install Python 3 and try again."; exit 1; }
	@command -v aws > /dev/null 2>&1 || { echo "AWS CLI is not installed. Please install AWS CLI and try again."; exit 1; }
	@command -v terraform > /dev/null 2>&1 || { echo "Terraform is not installed. Please install Terraform and try again."; exit 1; }
	@command -v jq > /dev/null 2>&1 || { echo "jq is not installed. Please install jq and try again."; exit 1; }
	@command -v localstack > /dev/null 2>&1 || { echo "LocalStack CLI is not installed. Run 'make install' or install it manually."; exit 1; }
	@command -v awslocal > /dev/null 2>&1 || { echo "awslocal is not installed. Run 'make install' or install it manually."; exit 1; }
	@echo "All required prerequisites are available."

install: ## Install LocalStack and awslocal dependencies
	@command -v python3 > /dev/null 2>&1 || { echo "Python 3 is not installed. Please install Python 3 and try again."; exit 1; }
	@python3 -m pip install --user --upgrade localstack awscli-local
	@echo "Installed/updated LocalStack CLI and awslocal."
	@echo "If 'localstack' or 'awslocal' are not found, add your Python user bin directory to PATH."

start: ## Start LocalStack
	@test -n "${LOCALSTACK_AUTH_TOKEN}" || (echo "LOCALSTACK_AUTH_TOKEN is not set. Find your token at https://app.localstack.cloud/workspace/auth-token"; exit 1)
	@LOCALSTACK_AUTH_TOKEN=$(LOCALSTACK_AUTH_TOKEN) localstack start -d

stop: ## Stop LocalStack
	@localstack stop

ready: ## Wait until LocalStack is ready
	@localstack wait -t 30 && echo LocalStack is ready to use! || (echo Gave up waiting on LocalStack, exiting. && exit 1)

logs: ## Retrieve LocalStack logs
	@localstack logs > logs.txt

.PHONY: usage check install start stop ready logs
