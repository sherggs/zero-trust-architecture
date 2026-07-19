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
