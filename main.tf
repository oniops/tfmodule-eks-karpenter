locals {
  region              = var.eks_context.region
  account_id          = var.eks_context.account_id
  cluster_name        = var.eks_context.cluster_name
  cluster_simple_name = var.eks_context.cluster_simple_name
  project             = var.eks_context.project
  tags                = var.eks_context.tags
  name_prefix         = var.eks_context.name_prefix
}

module "node" {
  source                       = "git::https://github.com/oniops/tfmodule-aws-eks-node?ref=v1.0.0"
  create                       = var.create
  eks_context                  = var.eks_context
  name                         = var.name
  ami_type                     = var.ami_type
  ami_id                       = var.ami_id
  desired_size                 = var.desired_size
  min_size                     = var.min_size
  max_size                     = var.max_size
  enable_bootstrap_user_data   = var.enable_bootstrap_user_data
  instance_types               = var.instance_types
  block_device_mappings        = var.block_device_mappings
  subnet_ids                   = var.subnet_ids
  bootstrap_extra_args         = var.bootstrap_extra_args
  node_role_arn                = var.node_role_arn
  iam_role_additional_policies = var.iam_role_additional_policies
  additional_tags              = var.additional_tags
  labels                       = var.labels
}
