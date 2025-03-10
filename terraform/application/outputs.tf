# output "apigateway_url" {
#   value = "http://${module.api_gateway.api_id}.execute-api.localhost:4566"
# }

# output "ecr_reop_url" {
#   value = aws_ecr_repository.app_ecr_repo.repository_url
# }

################# Public APIGateway for Dev ###############
resource "aws_api_gateway_rest_api" "hce-search-event-apigw-public" {
  name        = "exemption-events-api"
  description = "API for sending exemption events to SQS"
  tags = {
    "_custom_id_" : "exemptioneventsapi"
  }
}

resource "aws_api_gateway_resource" "hce-search-event-apigw-public-v1" {
  rest_api_id = aws_api_gateway_rest_api.hce-search-event-apigw-public.id
  parent_id   = aws_api_gateway_rest_api.hce-search-event-apigw-public.root_resource_id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "hce-search-event-apigw-public-v1-events" {
  rest_api_id = aws_api_gateway_rest_api.hce-search-event-apigw-public.id
  parent_id   = aws_api_gateway_resource.hce-search-event-apigw-public-v1.id
  path_part   = "events"
}

resource "aws_api_gateway_method" "hce-search-event-public-post-method" {
  rest_api_id   = aws_api_gateway_rest_api.hce-search-event-apigw-public.id
  resource_id   = aws_api_gateway_resource.hce-search-event-apigw-public-v1-events.id
  http_method   = "POST"
  authorization = "NONE"
}

# IAM
# IAM
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_caller_identity" "aws" {}

resource "aws_iam_role" "role" {
  name                = "myrole"
  assume_role_policy  = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSQSFullAccess"]
}

resource "aws_api_gateway_integration" "hce-search-event-public-post-integration" {
  credentials             = aws_iam_role.role.arn
  rest_api_id             = aws_api_gateway_rest_api.hce-search-event-apigw-public.id
  resource_id             = aws_api_gateway_resource.hce-search-event-apigw-public-v1-events.id
  http_method             = aws_api_gateway_method.hce-search-event-public-post-method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${data.aws_caller_identity.aws.account_id}/${aws_sqs_queue.exemption_events_creation.name}"
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  # Request Template to convert incoming JSON to the SQS format
  #set($timestamp = $context.requestTime)

  ## Add event.timestamp to the input JSON map
  #if(!$map.metadata)
  #set($map.metadata = {})
  #end
  #if(!$map.metadata.event)
  #set($map.metadata.event = {})
  #end
  #set($map.metadata.event.timestamp = $timestamp)

  ## Convert the map to a JSON string
  request_templates = {
    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
#set($map = $input.json())
Action=SendMessage&MessageBody="$map"
EOF
  }

}

resource "aws_api_gateway_method_response" "hce-search-event-public-post-method-RESPONSE_200" {
  rest_api_id = aws_api_gateway_rest_api.hce-search-event-apigw-public.id
  resource_id = aws_api_gateway_resource.hce-search-event-apigw-public-v1-events.id
  http_method = aws_api_gateway_method.hce-search-event-public-post-method.http_method
  depends_on  = [aws_api_gateway_method.hce-search-event-public-post-method]
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "hce-search-event-public-post-integration-RESPONSE_200" {
  rest_api_id = aws_api_gateway_rest_api.hce-search-event-apigw-public.id
  resource_id = aws_api_gateway_resource.hce-search-event-apigw-public-v1-events.id
  http_method = aws_api_gateway_method.hce-search-event-public-post-method.http_method
  status_code = aws_api_gateway_method_response.hce-search-event-public-post-method-RESPONSE_200.status_code
  depends_on  = [aws_api_gateway_integration.hce-search-event-public-post-integration]
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.hce-search-event-apigw-public.id
  stage_name  = "local"

  # Ensure this depends on all integration, responses, and methods being created first
  depends_on = [
    aws_api_gateway_integration.hce-search-event-public-post-integration,
    aws_api_gateway_integration_response.hce-search-event-public-post-integration-RESPONSE_200,
    aws_api_gateway_method_response.hce-search-event-public-post-method-RESPONSE_200,
    aws_api_gateway_method.hce-search-event-public-post-method,
    aws_api_gateway_resource.hce-search-event-apigw-public-v1-events,
    aws_api_gateway_resource.hce-search-event-apigw-public-v1
  ]
  triggers = {
    always = timestamp()
  }
}

output "api_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/v1/events"
}

resource "aws_sqs_queue" "exemption_events_creation" {
  name = "my-queue"
}
