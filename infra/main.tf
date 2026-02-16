module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace = local.namespace
  name      = local.name
}

data "aws_caller_identity" "current" {}

locals {
  profile    = var.profile
  region     = var.region
  identity   = data.aws_caller_identity.current
  account_id = local.identity.account_id
  name       = var.name
  namespace  = var.namespace
  id         = module.label.id
  # prefixes
  ssm_prefix = "${"/"}${join("/", compact([
    module.label.namespace != "" ? module.label.namespace : null,
    module.label.name != "" ? module.label.name : null
  ]))}"
  pascal_prefix = replace(title(module.label.id), "/\\W+/", "")
}

module "lambda" {
  source = "git::https://github.com/ql4b/terraform-aws-lambda-function.git?ref=v1.1.0"

  source_dir       = "../app/src"
  
  runtime         = "provided.al2023"
  handler         = "handler.run"
  architecture    = "arm64"

  memory_size     = 2048 # 1024 # 512 # 
  timeout         = 10

  layers = [
    module.bootstrap.layer_arn,
    module.jq.layer_arn # optional
  ]

  context         = module.label.context
  attributes      = ["function"]

  depends_on      = [ 
    module.bootstrap,
    module.jq # optional
  ]
}

resource "aws_lambda_function_url" "lambda" {
  function_name   = module.lambda.function_name
  authorization_type = "NONE"
  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    max_age           = 300
  }
}

module "bootstrap" {
  source      = "git::https://github.com/ql4b/terraform-aws-lambda-layer.git?ref=v1.0.0"
  
  context     = module.label.context
  attributes  = ["bootstap"]
  
  source_dir                = "../runtime/build"
  compatible_architectures  = ["arm64"]
  compatible_runtimes       = ["provided.al2023"]
}

# optional
module "jq" {
  source      = "git::https://github.com/ql4b/terraform-aws-lambda-layer.git?ref=v1.0.0"
  
  context     = module.label.context
  attributes  = ["jq"]
  
  source_dir                = "../layers/jq/layer/opt"
  compatible_architectures  = ["arm64"]
  compatible_runtimes       = ["provided.al2023"]
}