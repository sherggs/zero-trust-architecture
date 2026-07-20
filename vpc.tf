# Network layer. In a zero-trust design the network grants reach, never trust. Authorisation happens at each hop through IAM and not through IP ranges.

resource "aws_vpc" "zero_trust" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-flow-logs"
  retention_in_days = 30
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "${var.project_name}-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume.json
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name   = "${var.project_name}-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_permissions.json
}

resource "aws_flow_log" "zero_trust" {
  vpc_id               = aws_vpc.zero_trust.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
}

resource "aws_internet_gateway" "zero_trust" {
  vpc_id = aws_vpc.zero_trust.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

#tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.zero_trust.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.zero_trust.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.zero_trust.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
