# Security group: zero ingress rules. Egress limited to HTTPS which covers SSM, dnf repositories, and the API Gateway endpoint.
resource "aws_security_group" "client" {
  name        = "${var.project_name}-sg"
  description = "No ingress. HTTPS egress only."
  vpc_id      = aws_vpc.main.id

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
