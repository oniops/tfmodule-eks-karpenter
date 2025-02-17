################################################################################
# Node Termination Event Rules
################################################################################

locals {
  event_rule_prefix = "${local.name_prefix}-${local.cluster_simple_name}-${var.name}"

  events = {
    health_event = {
      name        = "HealthEvent"
      description = "Karpenter interrupt - AWS health event"
      event_pattern = {
        source = ["aws.health"]
        detail-type = ["AWS Health Event"]
      }
    }
    spot_interrupt = {
      name        = "SpotInterrupt"
      description = "Karpenter interrupt - EC2 spot instance interruption warning"
      event_pattern = {
        source = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      }
    }
    instance_rebalance = {
      name        = "InstanceRebalance"
      description = "Karpenter interrupt - EC2 instance rebalance recommendation"
      event_pattern = {
        source = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      }
    }
    instance_state_change = {
      name        = "InstanceStateChange"
      description = "Karpenter interrupt - EC2 instance state-change notification"
      event_pattern = {
        source = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      }
    }
  }
}


resource "aws_cloudwatch_event_rule" "this" {
  for_each    = {for k, v in local.events : k => v if local.enable_spot_termination}
  name        = "${local.event_rule_prefix}${each.value.name}Rule"
  description = each.value.description
  event_pattern = jsonencode(each.value.event_pattern)
  tags = merge(local.tags, {
    Name        = "${local.event_rule_prefix}${each.value.name}Rule"
    ClusterName = local.cluster_name
  })
}

resource "aws_cloudwatch_event_target" "this" {
  for_each  = {for k, v in local.events : k => v if local.enable_spot_termination}
  rule      = aws_cloudwatch_event_rule.this[each.key].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.this[0].arn
}
