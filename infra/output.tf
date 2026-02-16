output "env" {
  value = {
    profile    = local.profile
    region     = local.region
    namespace  = module.label.namespace
    name       = module.label.name
    id         = module.label.id
    account_id = local.account_id
  }
}

output "lambda" {
  value = { 
    function = module.lambda.function_name
    url = aws_lambda_function_url.lambda.function_url
  }
}

output "layers" {
  value = [
    module.bootstrap,
    module.jq
  ]
}