# Refer to the https://docs.aws.amazon.com/ for more documentation
# Scoped to GET only. A POST, PUT, or DELETE signed by this role fails at IAM evaluation even before API Gateway routing matters.
data "aws_iam_policy_document" "client_invoke" {
  statement {
    sid       = "InvokeInventoryGetOnly"
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.inventory.execution_arn}/*/GET/*"]
  }
}

#AMI for only aws owned linux image
data "aws_ami" "al2023" {
  # If you want to match multiple AMIs, use the aws_ami_ids data source instead.
  most_recent = true # use an ami id for this I am using most recent = true as a prefernce
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/build/read_inventory.zip"
}

data "aws_iam_policy_document" "lambda_permissions" {
  # zero_trust_table defines no GSI, so there is no index ARN to grant - Query/Scan run against the base table only.
  # If a GSI is added later, scope its resource to the specific index ARN rather than a "index/*" wildcard.
  statement {
    sid = "DynamoReadOnly"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [aws_dynamodb_table.zero_trust_table.arn]
  }

  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-read-inventory*"
    ]
  }

  # X-Ray's PutTraceSegments/PutTelemetryRecords API does not support resource-level permissions - AWS's own
  # AWSXRayDaemonWriteAccess managed policy scopes these to "*" for the same reason.
  statement {
    sid = "XRayWrite"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "apigateway_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_permissions" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    # Log stream ARNs live under the group ARN with a ":*" suffix - this is AWS's own documented least-privilege
    # pattern for flow-log delivery roles, not a broad grant. https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-iam-role.html
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"]
  }

  # DescribeLogGroups has no resource-level permissions - AWS requires "*" here.
  statement {
    actions = ["logs:DescribeLogGroups"]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }
}

# Deny-by-default resource policy. The Deny statement rejects any principal whose ARN differs from the client role. a
data "aws_iam_policy_document" "api_resource_policy" {
  statement {
    sid    = "AllowClientRole"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.client.arn]
    }

    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.inventory.execution_arn}/*/GET/*"]
  }

  statement {
    sid    = "DenyEveryoneElse"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.inventory.execution_arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalArn"
      values   = [aws_iam_role.client.arn]
    }
  }
}
