# ---------------------------------------------------------------------------
# OBSERVABILITY module (Phase 5) - SNS alerting, a CloudWatch alarm, a
# dashboard, GuardDuty, and Security Hub.
# (Container Insights agent/logs are enabled via the EKS cluster addon.)
# ---------------------------------------------------------------------------

# --- SNS topic + email subscription for alerts (Task 3) ---
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # NOTE: AWS sends a confirmation email; the subscription is pending until
  # the recipient clicks confirm.
}

# --- Alarm: ALB 5xx errors (Task 3). Fires when the load balancer returns
# a burst of 5xx responses - a meaningful "something is broken" signal. ---
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count               = var.alb_arn_suffix == "" ? 0 : 1
  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "ALB returned 5xx errors - app or targets unhealthy."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
  tags          = var.tags
}

# --- One CloudWatch dashboard (Task 2) ---
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Pod CPU utilization (Container Insights)"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", "ClusterName", var.cluster_name, "Namespace", "dev"]
          ]
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Pod memory utilization (Container Insights)"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["ContainerInsights", "pod_memory_utilization", "ClusterName", var.cluster_name, "Namespace", "dev"]
          ]
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB request count"
          region = var.region
          view   = "timeSeries"
          metrics = var.alb_arn_suffix == "" ? [] : [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }]
          ]
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB 5xx error count"
          region = var.region
          view   = "timeSeries"
          metrics = var.alb_arn_suffix == "" ? [] : [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }]
          ]
          period = 60
        }
      }
    ]
  })
}

# --- GuardDuty (Task 4) ---
resource "aws_guardduty_detector" "this" {
  enable = true
  tags   = var.tags
}

# --- Security Hub + AWS Foundational Best Practices standard (Task 5) ---
resource "aws_securityhub_account" "this" {}

resource "aws_securityhub_standards_subscription" "fsbp" {
  depends_on    = [aws_securityhub_account.this]
  standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}
