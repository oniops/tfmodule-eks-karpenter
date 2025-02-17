locals {

  karpenter_controller_policy_name = "${local.project}${title(local.cluster_simple_name)}${title(var.name)}ControllerPolicy"
  karpenter_controller_policy = templatefile("${path.module}/templates/policy-karpenter-controller-v1.0.tpl", {
    region            = local.region
    account_id        = local.account_id
    cluster_name      = local.cluster_name
    node_role_arn     = module.node.node_role_arn
    karpenter_sqs_arn = try(aws_sqs_queue.this[0].arn, "")
  })

}

resource "aws_iam_policy" "karpenter" {
  count       = local.create_karpenter_role ? 1 : 0
  name        = local.karpenter_controller_policy_name
  description = var.karpenter_policy_description
  policy      = local.karpenter_controller_policy
  tags = merge(local.tags, {
    Name = local.karpenter_controller_policy_name
  })
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  count      = local.create_karpenter_role ? 1 : 0
  role       = aws_iam_role.karpenter[0].name
  policy_arn = aws_iam_policy.karpenter[0].arn
}