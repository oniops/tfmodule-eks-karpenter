locals {
  create_karpenter_role = var.create
  karpenter_role_name   = "${local.project}${title(local.cluster_simple_name)}${title(var.name)}ControllerRole"
  karpenter_role_trusted = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "pods.eks.amazonaws.com"
        },
        "Action" : [
          "sts:TagSession",
          "sts:AssumeRole"
        ]
      }
    ]
  })

}

resource "aws_iam_role" "karpenter" {
  count                 = local.create_karpenter_role ? 1 : 0
  name                  = local.karpenter_role_name
  description           = var.karpenter_role_description
  assume_role_policy    = local.karpenter_role_trusted
  max_session_duration  = var.karpenter_role_max_session_duration
  force_detach_policies = true
  # permissions_boundary  = var.karpenter_role_permissions_boundary_arn

  tags = merge(local.tags, {
    Name = local.karpenter_role_name
  })
}


resource "aws_iam_role_policy_attachment" "karpenterAdditional" {
  for_each = {for k, v in var.karpenter_role_policies : k => v if local.create_karpenter_role}
  role       = aws_iam_role.karpenter[0].name
  policy_arn = each.value
}

################################################################################
# Pod Identity Association
################################################################################

resource "aws_eks_pod_identity_association" "karpenter" {
  count = local.create_karpenter_role && var.create_pod_identity_association ? 1 : 0
  cluster_name    = local.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.karpenter[0].arn
  tags = local.tags
}
