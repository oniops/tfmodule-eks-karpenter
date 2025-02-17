variable "eks_context" {
  type = object({
    account_id                = string
    region                    = string
    project                   = string
    owner                     = string
    team                      = string
    domain                    = string
    pri_domain                = string
    name_prefix               = string
    tags                      = map(string)

    # EKS
    cluster_name              = string
    cluster_simple_name       = string
    cluster_version           = string
    cluster_endpoint          = string
    cluster_auth_base64       = string
    service_ipv4_cidr         = string
    node_security_group_id    = string
  })
  description = <<-EOF

data "aws_eks_cluster" "this" {
  name = "<EKS_CLUSTER_NAME>"
}

eks_context = merge(module.ctx.context, {
    cluster_name           = data.aws_eks_cluster.this.name
    cluster_version        = data.aws_eks_cluster.this.version
    cluster_endpoint       = data.aws_eks_cluster.this.endpoint
    cluster_auth_base64    = data.aws_eks_cluster.this.certificate_authority[0].data
    service_ipv4_cidr      = data.aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr
    cluster_simple_name    = "cluster_simple_name"
    node_security_group_id = "<EKS_NODE_SECURITY_GROUP_ID>"
  })
EOF

}
