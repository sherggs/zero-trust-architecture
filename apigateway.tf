# API Gateway.
# Only a GET method exists. There is nothing else to call.

resource "aws_api_gateway_rest_api" "inventory" {
  name        = "${var.project_name}-api"
  description = "Front door for internal inventory reads"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "inventory" {
  rest_api_id = aws_api_gateway_rest_api.inventory.id
  parent_id   = aws_api_gateway_rest_api.inventory.root_resource_id
  path_part   = "inventory"
}

resource "aws_api_gateway_method" "get_inventory" {
  rest_api_id   = aws_api_gateway_rest_api.inventory.id
  resource_id   = aws_api_gateway_resource.inventory.id
  http_method   = "GET"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.inventory.id
  resource_id             = aws_api_gateway_resource.inventory.id
  http_method             = aws_api_gateway_method.get_inventory.http_method
  integration_http_method = "POST" # Lambda invocations are always POST at the integration layer
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.read_inventory.invoke_arn
}

resource "aws_api_gateway_rest_api_policy" "inventory" {
  rest_api_id = aws_api_gateway_rest_api.inventory.id
  policy      = data.aws_iam_policy_document.api_resource_policy.json

  depends_on = [
    aws_iam_role.client,
    aws_iam_role_policy.client_invoke,
  ]
}

resource "aws_api_gateway_deployment" "inventory" {
  rest_api_id = aws_api_gateway_rest_api.inventory.id

  # Redeploy whenever the method, integration, or policy changes.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.inventory.id,
      aws_api_gateway_method.get_inventory.id,
      aws_api_gateway_integration.lambda.id,
      data.aws_iam_policy_document.api_resource_policy.json,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_rest_api_policy.inventory,
  ]
}

resource "aws_api_gateway_stage" "production" {
  rest_api_id   = aws_api_gateway_rest_api.inventory.id
  deployment_id = aws_api_gateway_deployment.inventory.id
  stage_name    = "production"
}

# API Gateway needs explicit permission to invoke the function scoped to this API, this stage pattern, GET, and this path.
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read_inventory.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.inventory.execution_arn}/*/GET/inventory"
}
