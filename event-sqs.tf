################################################################################
# Node Termination Queue
################################################################################

locals {
  enable_spot_termination = var.create && var.enable_spot_termination
  sqs_name                = "${local.name_prefix}-${local.cluster_simple_name}-${var.name}-sqs"

  sqs_policy = templatefile("${path.module}/templates/policy-karpenter-sqs.tpl", {
    region            = local.region
    account_id        = local.account_id
    karpenter_sqs_arn = "arn:aws:sqs:${local.region}:${local.account_id}:${local.sqs_name}"
  })
}

resource "aws_sqs_queue" "this" {
  count                             = local.enable_spot_termination ? 1 : 0
  name                              = local.sqs_name
  message_retention_seconds         = var.message_retention_seconds
  sqs_managed_sse_enabled           = var.sqs_managed_sse_enabled ? var.sqs_managed_sse_enabled : null
  kms_master_key_id                 = var.sqs_kms_master_key_id
  kms_data_key_reuse_period_seconds = var.sqs_kms_data_key_reuse_period_seconds

  tags = merge(local.tags, {
    Name = local.sqs_name
  })
}

resource "aws_sqs_queue_policy" "this" {
  count     = local.enable_spot_termination ? 1 : 0
  queue_url = aws_sqs_queue.this[0].url
  policy    = local.sqs_policy
}
