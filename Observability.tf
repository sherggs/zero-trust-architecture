# Observability.
# Every rejected request against the API returns a 4XX and API Gateway counts them in the 4XXError metric
# A spike means someone is probing the endpoint or a legitimate client lost its permissions. Either way you want to know within minutes

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

# Subscription only exists when an email is supplied.
# SNS email subscriptions need manual confirmation, so Terraform creates the subscription and AWS emails you a confirmation link.
resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "api_4xx" {
  alarm_name        = "${var.project_name}-api-failed-requests"
  alarm_description = "Five or more rejected requests against the inventory API in five minutes"

  namespace   = "AWS/ApiGateway"
  metric_name = "4XXError"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.inventory.name
    Stage   = aws_api_gateway_stage.production.stage_name
  }

  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"

  # No traffic means no data, and no data means nothing is wrong. Without this, a quiet API flaps between INSUFFICIENT_DATA and OK.
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
