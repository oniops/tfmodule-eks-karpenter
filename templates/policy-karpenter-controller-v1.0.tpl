{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowScopedEC2InstanceAccessActions",
            "Effect": "Allow",
            "Action": [
                "ec2:RunInstances",
                "ec2:CreateFleet"
            ],
            "Resource": [
				"arn:aws:ec2:${region}::snapshot/*",
				"arn:aws:ec2:${region}::image/*",
				"arn:aws:ec2:${region}:*:subnet/*",
				"arn:aws:ec2:${region}:*:security-group/*"
            ]
        },
        {
            "Sid": "AllowScopedEC2LaunchTemplateAccessActions",
            "Effect": "Allow",
            "Action": [
                "ec2:RunInstances",
                "ec2:CreateFleet"
            ],
            "Resource": "arn:aws:ec2:${region}:*:launch-template/*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/kubernetes.io/cluster/${cluster_name}": "owned"
                },
                "StringLike": {
                    "aws:ResourceTag/karpenter.sh/nodepool": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedEC2InstanceActionsWithTags",
            "Effect": "Allow",
            "Action": [
                "ec2:RunInstances",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateFleet"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:volume/*",
                "arn:aws:ec2:*:*:spot-instances-request/*",
                "arn:aws:ec2:*:*:network-interface/*",
                "arn:aws:ec2:*:*:launch-template/*",
                "arn:aws:ec2:*:*:instance/*",
                "arn:aws:ec2:*:*:fleet/*"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:RequestTag/eks:eks-cluster-name": "${cluster_name}",
                    "aws:RequestTag/kubernetes.io/cluster/${cluster_name}": "owned"
                },
                "StringLike": {
                    "aws:RequestTag/karpenter.sh/nodepool": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedResourceCreationTagging",
            "Effect": "Allow",
            "Action": "ec2:CreateTags",
            "Resource": [
                "arn:aws:ec2:*:*:volume/*",
                "arn:aws:ec2:*:*:spot-instances-request/*",
                "arn:aws:ec2:*:*:network-interface/*",
                "arn:aws:ec2:*:*:launch-template/*",
                "arn:aws:ec2:*:*:instance/*",
                "arn:aws:ec2:*:*:fleet/*"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:RequestTag/eks:eks-cluster-name": "${cluster_name}",
                    "aws:RequestTag/kubernetes.io/cluster/${cluster_name}": "owned",
                    "ec2:CreateAction": [
                        "RunInstances",
                        "CreateFleet",
                        "CreateLaunchTemplate"
                    ]
                },
                "StringLike": {
                    "aws:RequestTag/karpenter.sh/nodepool": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedResourceTagging",
            "Effect": "Allow",
            "Action": "ec2:CreateTags",
            "Resource": "arn:aws:ec2:*:*:instance/*",
            "Condition": {
                "ForAllValues:StringEquals": {
                    "aws:TagKeys": [
                        "eks:eks-cluster-name",
                        "karpenter.sh/nodeclaim",
                        "Name"
                    ]
                },
                "StringEquals": {
                    "aws:ResourceTag/kubernetes.io/cluster/${cluster_name}": "owned"
                },
                "StringEqualsIfExists": {
                    "aws:RequestTag/eks:eks-cluster-name": "${cluster_name}"
                },
                "StringLike": {
                    "aws:ResourceTag/karpenter.sh/nodepool": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedDeletion",
            "Effect": "Allow",
            "Action": [
                "ec2:TerminateInstances",
                "ec2:DeleteLaunchTemplate"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:launch-template/*",
                "arn:aws:ec2:*:*:instance/*"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/kubernetes.io/cluster/${cluster_name}": "owned"
                },
                "StringLike": {
                    "aws:ResourceTag/karpenter.sh/nodepool": "*"
                }
            }
        },
        {
            "Sid": "AllowRegionalReadActions",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeSubnets",
                "ec2:DescribeSpotPriceHistory",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeInstanceTypeOfferings",
                "ec2:DescribeImages",
                "ec2:DescribeAvailabilityZones"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestedRegion": "${region}"
                }
            }
        },
        {
            "Sid": "AllowSSMReadActions",
            "Effect": "Allow",
            "Action": "ssm:GetParameter",
            "Resource": "arn:aws:ssm:${region}::parameter/aws/service/*"
        },
        {
            "Sid": "AllowPricingReadActions",
            "Effect": "Allow",
            "Action": "pricing:GetProducts",
            "Resource": "*"
        },
%{ if karpenter_sqs_arn != "" }
        {
            "Sid": "AllowInterruptionQueueActions",
            "Effect": "Allow",
            "Action": [
                "sqs:ReceiveMessage",
                "sqs:GetQueueUrl",
                "sqs:DeleteMessage"
            ],
            "Resource": "${karpenter_sqs_arn}"
        },%{ endif }
        {
            "Sid": "AllowPassingInstanceRole",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "${node_role_arn}",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "ec2.amazonaws.com"
                }
            }
        },
        {
            "Sid": "AllowScopedInstanceProfileCreationActions",
            "Effect": "Allow",
            "Action": "iam:CreateInstanceProfile",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestTag/eks:eks-cluster-name": "${cluster_name}",
                    "aws:RequestTag/kubernetes.io/cluster/${cluster_name}": "owned",
                    "aws:RequestTag/topology.kubernetes.io/region": "${region}"
                },
                "StringLike": {
                    "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedInstanceProfileTagActions",
            "Effect": "Allow",
            "Action": "iam:TagInstanceProfile",
            "Resource": "arn:aws:iam::${account_id}:instance-profile/*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestTag/eks:eks-cluster-name": "${cluster_name}",
                    "aws:RequestTag/kubernetes.io/cluster/${cluster_name}": "owned",
                    "aws:ResourceTag/kubernetes.io/cluster/${cluster_name}": "owned",
                    "aws:RequestTag/topology.kubernetes.io/region": "${region}",
                    "aws:ResourceTag/topology.kubernetes.io/region": "${region}"
                },
                "StringLike": {
                    "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*",
                    "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*"
                }
            }
        },
        {
            "Sid": "AllowScopedInstanceProfileActions",
            "Effect": "Allow",
            "Action": [
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:AddRoleToInstanceProfile"
            ],
            "Resource": "arn:aws:iam::${account_id}:instance-profile/*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/kubernetes.io/cluster/${cluster_name}": "owned",
                    "aws:ResourceTag/topology.kubernetes.io/region": "${region}"
                },
                "StringLike": {
                    "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*"
                }
            }
        },
        {
            "Sid": "AllowInstanceProfileReadActions",
            "Effect": "Allow",
            "Action": "iam:GetInstanceProfile",
            "Resource": "arn:aws:iam::${account_id}:instance-profile/*"
        },
        {
            "Sid": "AllowAPIServerEndpointDiscovery",
            "Effect": "Allow",
            "Action": "eks:DescribeCluster",
            "Resource": "arn:aws:eks:${region}:${account_id}:cluster/${cluster_name}"
        }
    ]
}