output "api_invoke_url" {
  description = "Invoke URL for the inventory endpoint"
  value       = "${aws_api_gateway_stage.production.invoke_url}/inventory"
}

output "instance_id" {
  description = "EC2 client instance ID"
  value       = aws_instance.client.id
}

output "table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.zero_trust_table.name
}

output "ssm_session_command" {
  description = "Open a shell on the client without SSH"
  value       = "aws ssm start-session --target ${aws_instance.client.id} --region ${var.aws_region}"
}

output "test_command_from_instance" {
  description = "Run inside the SSM session to test the signed GET"
  value       = "awscurl --service execute-api --region ${var.aws_region} ${aws_api_gateway_stage.production.invoke_url}/inventory"
}
