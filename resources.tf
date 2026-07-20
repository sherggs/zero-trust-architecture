# Security group: zero ingress rules. Egress limited to HTTPS which covers SSM, dnf repositories, and the API Gateway endpoint.
resource "aws_security_group" "client" {
  name        = "${var.project_name}-sg"
  description = "No ingress. HTTPS egress only."
  vpc_id      = aws_vpc.zero_trust.id

  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  egress {
    description = "HTTPS out for SSM, package repos, API Gateway"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "aws_iam_role" "client" {
  name               = "${var.project_name}-client-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# SSM Session Manager needs this managed policy. The agent registers with SSM and streams the session over the outbound channel.
resource "aws_iam_role_policy_attachment" "client_ssm" {
  role       = aws_iam_role.client.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "client_invoke" {
  name   = "${var.project_name}-invoke-get"
  role   = aws_iam_role.client.id
  policy = data.aws_iam_policy_document.client_invoke.json
}

resource "aws_iam_instance_profile" "client" {
  name = "${var.project_name}-client-profile"
  role = aws_iam_role.client.name
}

resource "aws_instance" "client" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.client.id]
  iam_instance_profile   = aws_iam_instance_profile.client.name

  # No key_name attribute. Without a key pair, SSH has no credential even if someone later opens port 22.
  # IMDSv2 only. Blocks SSRF-style credential theft from the instance metadata service by requiring a session token.
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted = true
  }

  # awscurl signs requests with SigV4 using the instance role credentials, so you test the IAM-auth path with one command.
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3-pip
    pip3 install awscurl
  EOF

  tags = {
    Name = "${var.project_name}-client"
  }
}

