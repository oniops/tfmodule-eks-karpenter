variable "create" {
  type    = bool
  default = true
}

variable "name" {
  description = "Name of the EKS managed node group"
  type        = string
  default     = "karpenter"
}


variable "ami_type" {
  type        = string
  description = <<EOF
Type of Amazon Machine Image (AMI) associated with the EKS Node Group. See the [AWS documentation](https://docs.aws.amazon.com/eks/latest/APIReference/API_Nodegroup.html#AmazonEKS-Type-Nodegroup-amiType) for valid values
Valid Values: AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | CUSTOM
    | BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64 | BOTTLEROCKET_ARM_64_NVIDIA | BOTTLEROCKET_x86_64_NVIDIA
    | WINDOWS_CORE_2019_x86_64 | WINDOWS_FULL_2019_x86_64 | WINDOWS_CORE_2022_x86_64 | WINDOWS_FULL_2022_x86_64
    | AL2023_x86_64_STANDARD | AL2023_ARM_64_STANDARD | AL2023_x86_64_NEURON | AL2023_x86_64_NVIDIA
EOF
}

variable "ami_id" {
  type        = string
  description = <<-EOF
The Custom AMI from which to launch the instance. If not supplied, EKS will use its own default image.
In case of BOTTLEROCKET_ARM_64 type, you can find latest AMI_ID from global parameter-store.

Ex)
  aws ssm get-parameter --name "/aws/service/bottlerocket/aws-k8s-1.31/arm64/latest/image_id
EOF
}


# ################################################################################
# # EKS Managed Node Group
# ################################################################################

variable "min_size" {
  description = "Minimum number of instances/nodes"
  type        = number
  default     = 0
}

variable "max_size" {
  description = "Maximum number of instances/nodes"
  type        = number
  default     = 3
}

variable "desired_size" {
  description = "Desired number of instances/nodes"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "Identifiers of EC2 Subnets to associate with the EKS Node Group. These subnets must have the following resource tag: `kubernetes.io/cluster/CLUSTER_NAME`"
  type = list(string)
}

variable "instance_types" {
  type = list(string)
  default     = null
  description = <<-EOF
Set of instance types associated with the EKS Node Group. Defaults to `["t3.medium"]`

  instance_types = [
    "t4g.small",
    "t4g.medium",
    "t4g.large",
    "t4g.xlarge",
    "r7g.medium",
    "r7g.large",
    "r7g.xlarge",
    "m7g.medium",
    "m7g.large",
    "m7g.xlarge",
    "c7g.medium",
    "c7g.large",
    "c7g.xlarge",
    "r8g.medium",
    "r8g.large",
    "r8g.xlarge",
  ]
EOF

}

variable "block_device_mappings" {
  description = <<EOF
Specify volumes to attach to the instance besides the volumes specified by the AMI
Can be standard, gp2, gp3, io1, io2, sc1 or st1 (Default: gp3).

  block_device_mappings = [{
    device_name           = "/dev/xvda" # ROOT Volume
    volume_type           = "gp3"
    volume_size           = 100
    delete_on_termination = true
    encrypted             = false
    kms_key_id            = ""
    iops                  = 3000
    throughput            = 125
  }]
EOF
  type        = any
}

variable "labels" {
  description = "Key-value map of Kubernetes labels. Only labels that are applied with the EKS API are managed by this argument. Other Kubernetes labels applied to the EKS Node Group will not be managed"
  type = map(string)
  default = {}
}

################################################################################
# IAM Role
################################################################################

variable "node_role_arn" {
  description = "Existing IAM role ARN for the node group. Required if `create_iam_role` is set to `false`"
  type        = string
  default     = null
}

variable "iam_role_additional_policies" {
  type = map(string)
  default = {}
  description = <<-EOF
Additional policies to be added to the IAM role

  iam_role_additional_policies = {
    AmazonSsmManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    AmazonEKSVPCResourceController     = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
    AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }
EOF
}

variable "karpenter_role_description" {
  description = "IAM role description for Karpenter Controller"
  type        = string
  default     = "Karpenter controller IAM role"
}

variable "karpenter_role_max_session_duration" {
  description = "IAM role description for Karpenter Controller"
  type        = string
  default     = null
}

variable "karpenter_policy_description" {
  description = "IAM policy description for Karpenter Controller"
  type        = string
  default     = "Karpenter controller IAM Policy"
}

variable "karpenter_role_policies" {
  type        = map(string)
  default     = {}
  description = <<-EOF
Policies to attach to the IAM role in `{'static_name' = 'policy_arn'}` format

  karpenter_role_policies = {
    KarpenterSQSKMSAccess = module.karpenter_sqs_kms_access_iam_policy.arn
  }
EOF
}

################################################################################
# Pod Identity Association
################################################################################

variable "create_pod_identity_association" {
  description = "Determines whether to create pod identity association"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Namespace to associate with the Karpenter Pod Identity"
  type        = string
  default     = "kube-system"
}

variable "service_account" {
  description = "Service account to associate with the Karpenter Pod Identity"
  type        = string
  default     = "karpenter"
}

################################################################################
# IAM Role for Service Account (IRSA)
################################################################################

variable "enable_irsa" {
  description = "Determines whether to enable support for IAM role for service accounts"
  type        = bool
  default     = true
}

variable "irsa_oidc_provider_arn" {
  type        = string
  description = <<EOF
OIDC provider arn used in trust policy for IAM role for service accounts.

  locals {
    oidc_provider_issuer = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
    oidc_provider_arn = "arn:aws:iam::111122223333:oidc-provider/{local.oidc_provider_issuer}"
  }

  irsa_oidc_provider_arn = local.oidc_provider_arn
EOF
}

variable "irsa_namespace_service_accounts" {
  description = "List of `namespace:serviceaccount`pairs to use in trust policy for IAM role for service accounts"
  type        = list(string)
  default     = ["karpenter:karpenter"]
}

################################################################################
# User Data for Launch Template
################################################################################

variable "enable_bootstrap_user_data" {
  description = "Determines whether the bootstrap configurations are populated within the user data template. Only valid when using a custom AMI via `ami_id`"
  type        = bool
  default     = true
}

variable "pre_bootstrap_user_data" {
  description = "User data that is injected into the user data script ahead of the EKS bootstrap script. Not used when `platform` = `bottlerocket`"
  type        = string
  default     = ""
}

variable "post_bootstrap_user_data" {
  description = "User data that is appended to the user data script after of the EKS bootstrap script. Not used when `platform` = `bottlerocket`"
  type        = string
  default     = ""
}

variable "bootstrap_extra_args" {
  description = "Additional arguments passed to the bootstrap script. When `platform` = `bottlerocket`; these are additional [settings](https://github.com/bottlerocket-os/bottlerocket#settings) that are provided to the Bottlerocket user data"
  type        = string
  default     = ""
}

variable "user_data_template_path" {
  description = "Path to a local, custom user data template file to use when rendering user data"
  type        = string
  default     = ""
}

variable "cluster_service_cidr" {
  description = "The CIDR block to assign Kubernetes service IP addresses from. If you don't specify a block, Kubernetes assigns addresses from either the 10.100.0.0/16 or 172.20.0.0/16 CIDR blocks"
  type        = string
  default     = null
}

variable "cloudinit_pre_nodeadm" {
  description = "Array of cloud-init document parts that are created before the nodeadm document part"
  type = list(object({
    content = string
    content_type = optional(string)
    filename = optional(string)
    merge_type = optional(string)
  }))
  default = []
}

variable "cloudinit_post_nodeadm" {
  description = "Array of cloud-init document parts that are created after the nodeadm document part"
  type = list(object({
    content = string
    content_type = optional(string)
    filename = optional(string)
    merge_type = optional(string)
  }))
  default = []
}

variable "additional_tags" {
  description = "A map of additional tags to add to the Node Group created"
  type = map(string)
  default = {}
}

################################################################################
# Node Termination Queue
################################################################################

variable "enable_spot_termination" {
  description = "Determines whether to enable native spot termination handling"
  type        = bool
  default     = true
}

variable "sqs_managed_sse_enabled" {
  description = "Boolean to enable server-side encryption (SSE) of message content with SQS-owned encryption keys"
  type        = bool
  default     = true
}

variable "message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message."
  type        = number
  default     = 300
}

variable "sqs_kms_master_key_id" {
  description = "The ID of an AWS-managed customer master key (CMK) for Amazon SQS or a custom CMK"
  type        = string
  default     = null
}

variable "sqs_kms_data_key_reuse_period_seconds" {
  description = "The length of time, in seconds, for which Amazon SQS can reuse a data key to encrypt or decrypt messages before calling AWS KMS again"
  type        = number
  default     = null
}

