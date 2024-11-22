output "apigateway_url" {
  value = "http://${module.api_gateway.api_id}.execute-api.localhost:4566"
}
