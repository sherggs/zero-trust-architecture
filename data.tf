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
  statement {
    sid = "DynamoReadOnly"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      aws_dynamodb_table.zero_trust_table.arn,
      "${aws_dynamodb_table.zero_trust_table.arn}/index/*",
    ]
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
}

