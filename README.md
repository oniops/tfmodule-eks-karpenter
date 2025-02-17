# tfmodule-eks-karpenter

EKS 에 최적화된 Karpenter 플러그인을 구성합니다. `tfmodule-aws-eks-node` 테라폼 모듈과 의존성이 있습니다.

## Git

```
git clone ssh://git@code.bespinglobal.com/op/tfmodule-eks-karpenter.git

cd tfmodule-eks-karpenter
```

## Build

```
terraform init

sh deploy.sh plan

sh deploy.sh apply
```

## Usage

```hcl
module "ctx" {
  source  = "git::https://code.bespinglobal.com/scm/op/tfmodule-context.git?ref=v1.2.0"
  context = var.context
}

locals {
  region       = module.ctx.region
  project      = module.ctx.project
  name_prefix  = module.ctx.name_prefix
  role_prefix  = "${local.project}${title(var.cluster_simple_name)}"
  cluster_name = "${local.name_prefix}-${var.cluster_simple_name}-eks"
  eks_context = merge(module.ctx.context, {
    cluster_name           = local.cluster_name
    cluster_simple_name    = var.cluster_simple_name
    cluster_version        = data.aws_eks_cluster.this.version
    cluster_endpoint       = data.aws_eks_cluster.this.endpoint
    cluster_auth_base64    = data.aws_eks_cluster.this.certificate_authority[ 0 ].data
    service_ipv4_cidr      = data.aws_eks_cluster.this.kubernetes_network_config[ 0 ].service_ipv4_cidr
    node_security_group_id = data.aws_security_group.node.id
  })

}


module "kpt" {
  source                     = "git::https://code.bespinglobal.com/scm/op/tfmodule-eks-karpenter?ref=v1.0.0"
  create                     = true
  eks_context                = local.eks_context
  name                       = var.name
  ami_type                   = "BOTTLEROCKET_ARM_64"
  ami_id                     = "ami-009fab5adfe7c6e1d"
  enable_bootstrap_user_data = true
  instance_types             = [ "t4g.small" ]
  block_device_mappings = [
    {
      device_name           = "/dev/xvda"
      volume_type           = "gp3"
      volume_size           = 100
      delete_on_termination = false
      encrypted             = true
      kms_key_id            = data.aws_kms_alias.ebs.target_key_arn
      iops                  = 3000
      throughput            = 125
    }
  ]
  subnet_ids = data.aws_subnets.grax.ids
  
  bootstrap_extra_args = <<-EOT
# The admin host container provides SSH access and runs with "superpowers".
# It is disabled by default, but can be disabled explicitly.
[settings.host-containers.admin]
enabled = false

# The control host container provides out-of-band access via SSM.
# It is enabled by default, and can be disabled if you do not expect to use SSM.
# This could leave you with no way to access the API and change settings on an existing node!
[settings.host-containers.control]
enabled = true

# extra args added
[settings.kernel]
lockdown = "integrity"
  EOT
  
  // node_role_arn = "arn:aws:iam::111122223333:role/YourCusomNodeRoleARN"
  
  iam_role_additional_policies = {
    AmazonSsmManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    AmazonEKSVPCResourceController     = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
    AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }
  
  additional_tags = {
    NodeGroupName = var.name
    NodeGroupType = "eks-managed-node-group"
  }
  
  labels = {
    "node.role"               = var.name
    "karpenter.sh/controller" = "true"
  }
  
  

}
```




## AWS Karpenter 개요
Karpenter는 AWS EKS(Elastic Kubernetes Service) 클러스터에서 자동으로 EC2 워커 노드를 프로비저닝 및 스케일링하는 오픈소스 노드 자동 확장 솔루션입니다.
EKS Cluster Autoscaler(CA)와 비교하여 빠른 프로비저닝, 다양한 EC2 인스턴스 타입 활용, 커스텀 로직 기반 확장 등의 이점을 제공합니다.

### 핵심 기능 

<table>
<thead>
<tr>
    <th>기능</th>
    <th>특징</th>
</tr>
</thead>
<tbody>
<tr>
    <td>즉각적인 노드 프로비저닝</td>
    <td>
- 기존 CA보다 빠르게 EC2 노드를 생성 및 제거함. <br> 
- 필요할 때 즉시 EC2 인스턴스를 프로비저닝하여 대기 시간을 줄임.
    </td>
</tr>
<tr>
    <td>광범위한 인스턴스 선택</td>
    <td>
- EC2 온디맨드, 스팟 인스턴스를 자동으로 선택하여 비용 최적화 가능. <br> 
- 특정 인스턴스 패밀리/크기 또는 가용 영역을 지정할 수 있음.
    </td>
</tr>
<tr>
    <td>워크로드 기반 자동 조정</td>
    <td>
- Provisioner 리소스를 활용하여 워크로드 요구 사항을 기반으로 맞춤형 확장이 가능.. <br> 
- 라벨 및 태그 기반 노드 프로비저닝 지원.
    </td>
</tr>
<tr>
    <td>불필요한 노드 자동 정리</td>
    <td>
- 노드가 불필요할 경우, 자동으로 종료하여 비용 절감 가능.
    </td>
</tr>
</tbody>
</table>


## Karpenter 컴포넌트 및 스팩

### Karpenter Controller
karpenter-controller 1.0 버전 이상에 동작하도록 IAM Policy 정책을 구성



### 스케줄링을 위한 SQS 및 EventBridge 구성
Karpenter는 EKS 클러스터 내에서 노드(EC2 인스턴스)와 파드 스케줄링을 최적화하기 위해 동적으로 리소스를 프로비저닝하고 해제하는 역할을 합니다.

이를 위해 AWS 이벤트 규칙과 통합함으로써 EC2 인스턴스의 상태 변화, 리밸런싱 요구, 예약된 변경 사항, Spot 인스턴스 중단 등 다양한 상황을 감지하고 적절하게 대응함은 물론 클러스터 내 자원 관리와 파드 스케줄링이 자동화되고 최적화됩니다.
또한, AWS SQS와의 통합은 이벤트 처리를 비동기적으로 안전하게 수행함으로써, 이벤트 폭주나 일시적인 장애 상황에도 시스템의 안정성과 확장성을 유지할 수 있도록 돕습니다.

이러한 구성은 EKS 클러스터 운영에서 노드 관리와 파드 스케줄링의 효율성을 극대화하며, 비용 효율적인 클라우드 인프라 운영에 크게 기여합니다.

#### AWS SQS Queue
AWS EventBridge를 통해 발생하는 다양한 이벤트들을 즉시 Karpenter가 처리하기 어려운 경우, SQS 큐에 이벤트를 저장하여 비동기적으로 처리할 수 있도록 합니다.
특히 급증하는 이벤트를 안정적으로 버퍼링하여 처리 지연이나 데이터 손실 없이 순차적으로 작업할 수 있게 합니다.

- 장애 격리: SQS 큐를 사용하면, 이벤트 생성과 처리 로직이 분리되어 한쪽에 장애가 발생하더라도 전체 시스템에 영향을 주지 않습니다.
- 처리량 확장: 이벤트가 많은 상황에서도 큐에 쌓인 메시지를 안정적으로 처리할 수 있으므로, 클러스터의 확장성 및 내구성을 높입니다.
- 이벤트 분산 및 재처리: SQS는 메시지의 중복 수신 및 재처리를 지원하여, 일시적인 처리 실패나 오류 상황에서도 이벤트가 안전하게 처리될 수 있도록 보장합니다.

#### InstanceStateChangeRule

EC2 인스턴스의 상태(예: pending, running, stopping, stopped, terminated)가 변경될 때 이를 감지하여 클러스터의 현재 상태와 동기화합니다.

- 노드 생명주기 관리: 인스턴스가 시작되거나 종료될 때, Karpenter는 이를 즉시 인지하여 새 노드의 준비 완료 상태를 반영하거나, 종료된 노드를 클러스터 상태에서 제거합니다.
- 파드 스케줄링 최적화: 인스턴스 상태 변화를 기반으로 파드의 스케줄링 또는 재스케줄링 결정을 내립니다.

#### RebalanceRule
클러스터 내에서 자원의 효율성을 극대화하고, 노드 간의 부하 분산을 개선하기 위한 리밸런싱 이벤트를 처리합니다.

- 리소스 최적화: 특정 노드에 부하가 집중되거나, 더 효율적인 노드 배치가 가능한 경우 해당 이벤트를 통해 리밸런싱 작업을 시작합니다.
- 비용 절감: 과도한 자원 사용을 방지하고, 필요한 경우 기존 노드를 종료하고 더 효율적인 인스턴스로 대체하는 등의 작업을 지원합니다.

#### ScheduledChangeRule
AWS에서 사전 예약된 변경 작업(예: 인스턴스 유지보수, 예정된 업그레이드 등)이나 주기적으로 발생하는 점검 이벤트를 감지하여, 클러스터 운영에 미치는 영향을 최소화합니다.

- 예측 가능한 유지보수 대응: AWS가 미리 공지하는 스케줄 변경(예: 인스턴스 리부팅, 하드웨어 교체 등)에 대해 미리 알림을 받고, 해당 인스턴스에 배포된 파드들의 graceful termination 및 재스케줄링을 준비합니다.
- 주기적 상태 점검: 예약된 이벤트를 기반으로 클러스터의 상태를 주기적으로 점검하고, 필요한 스케일링 또는 리밸런싱 작업을 계획할 수 있습니다.

#### SpotInterruptionRule
Spot 인스턴스를 사용하는 경우, AWS는 인스턴스 중단 예정 알림(약 2분 전)을 제공합니다. 이 이벤트는 Spot 인스턴스의 중단 가능성을 미리 감지하여 대비하는 데 필요합니다.

- 중단 대응: Spot 인스턴스에 할당된 파드들을 안전하게 다른 노드로 이동시키거나, 새 노드를 빠르게 프로비저닝하여 서비스 중단 없이 대응합니다.
- 서비스 안정성 유지: Spot 인스턴스 중단으로 인한 예기치 않은 장애를 완화하고, 클러스터의 전반적인 안정성을 높입니다.


## Karpenter 고급 활용 방안

### 비용 최적화 (온디맨드 & 스팟 혼합)
- 비용을 줄이기 위해 먼저 스팟 인스턴스를 요청하고, 가용성이 부족할 경우 온디맨드 인스턴스로 대체하도록 구성.
- Provisioner 설정에서 capacityType: spot을 기본으로 설정하고, ondemand로 fallback 가능.

```
provider:
  instanceProfile: "KarpenterNodeInstanceProfile"
  requirements:
    - key: "karpenter.k8s.aws/capacity-type"
      operator: In
      values: ["spot", "on-demand"]
```

### 특정 워크로드 최적화
- GPU 워크로드를 위해 p3, g4dn 등의 GPU 인스턴스를 지정할 수 있음.
- Fargate와 Karpenter를 병행하여 특정 Pod를 Fargate에 할당하고, 나머지 워크로드는 Karpenter로 처리.

```
requirements:
  - key: "karpenter.k8s.aws/instance-category"
    operator: In
    values: ["p3", "g4dn"]
```

### Reserved Capacity 사용
- Karpenter는 RI(예약 인스턴스) 및 Savings Plans과 함께 사용할 수 있음.
- provisioner 설정에서 특정 RI 인스턴스 타입을 지정하여 활용 가능.

```
requirements:
  - key: "karpenter.k8s.aws/capacity-type"
    operator: In
    values: ["on-demand"]
```

### Spot Instance 중단 감지 및 미리 대체
- 스팟 인스턴스 중단을 감지하고 미리 대체 노드를 생성하여 장애를 방지할 수 있음.
- karpenter.sh/do-not-evict 주석을 활용하여 특정 Pod가 중단되지 않도록 설정.

```
metadata:
  annotations:
    karpenter.sh/do-not-evict: "true"
```


### Pod 스케줄링에 대한 세밀한 제어
Pod의 affinity 및 tolerations 설정을 활용하여 특정 노드 그룹에만 배포 가능.

```
tolerations:
  - key: "karpenter.k8s.aws/capacity-type"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
```





## Appendix


### Karpenter Controller를 위한 IRSA 기반 IAM 정책

Karpenter Controller는 EKS 클러스터 내부에서 실행되며, 클러스터의 스케줄링 요구에 따라 동적으로 EC2 인스턴스를 생성, 수정, 종료하는 작업을 수행합니다. 이를 위해 AWS API(예: EC2, EC2 Auto Scaling, EC2 Spot 등)를 호출해야 하는데, 이때 필요한 권한을 IRSA를 통해 서비스 계정에 부여합니다.
IRSA를 사용하면 컨트롤러가 특정 서비스 계정에만 권한을 부여받아 작업을 수행하므로, 불필요한 권한 상승을 막고 보안성을 높일 수 있습니다.


#### 목적

- 노드 프로비저닝: 클러스터 내 워크로드가 증가하여 추가 노드가 필요할 때, Karpenter Controller는 IRSA를 통해 할당된 권한으로 ec2:RunInstances 등의 API를 호출하여 조건에 맞는 EC2 인스턴스를 생성합니다.
- 노드 종료 및 교체: 자원 사용량이 감소하거나, Spot 인스턴스 중단 알림(SpotInterruptionRule)에 따라 중단이 예상될 때, Controller는 ec2:TerminateInstances 등의 권한으로 적절한 인스턴스를 종료하거나 교체하는 작업을 진행합니다.
- 리밸런싱 및 상태 모니터링: 클러스터의 노드 상태 변화(InstanceStateChangeRule)나 예약된 유지보수(ScheduledChangeRule)에 대응하여, 현재 상태를 반영하고 리밸런싱 결정을 내리기 위한 API 호출에도 활용됩니다.

#### 요약
- 특징: IRSA를 통해 클러스터 내부에서 실행되는 컨트롤러에게 최소한의 AWS 권한을 부여하여 보안을 강화
- 대상: Karpenter Controller Pod(서비스 계정)
- 주요 권한: EC2 인스턴스 생성/종료, 상태 조회, 태그 관리 등



### EC2 노드를 위한 인스턴스 프로파일용 IAM 정책
Karpenter Controller가 프로비저닝한 EC2 인스턴스(노드)는 EKS 클러스터에 가입하여 파드를 호스팅하게 됩니다. 이를 위해 해당 노드가 EKS API와 상호작용할 수 있도록 최소한의 권한이 필요합니다.
Data Plane 용 노드가 ECR에서 컨테이너 이미지를 가져오거나, CloudWatch 로그/메트릭 전송 등 AWS 서비스와의 연동이 필요한 경우에 해당 권한을 부여합니다.


#### 목적
- EKS 클러스터 가입: 새로운 EC2 노드가 시작되면, 인스턴스 프로파일에 부여된 권한을 이용해 EKS 클러스터에 안전하게 가입하고, 워커 노드로 역할을 수행합니다.
- 이미지 풀(Pull) 권한: 노드에서 실행되는 kubelet이나 컨테이너 런타임이 ECR에서 필요한 이미지를 가져올 때, 인스턴스 프로파일에 할당된 IAM 권한이 사용됩니다.
- AWS 서비스와의 상호작용: CloudWatch 로그 전송, 메트릭 수집 등 노드 수준에서 AWS 서비스와 연동하는 경우에도 필요한 최소 권한을 부여합니다.

#### 요약
- 특징: 최소 권한 원칙에 따라 노드가 클러스터와 AWS 서비스에 안전하게 접근할 수 있도록 구성
- 대상: Karpenter가 프로비저닝한 EC2 인스턴스(노드)
- 주요 권한: EKS 클러스터 가입, ECR 이미지 접근, CloudWatch 로그/메트릭 전송 등

  
### 리소스 태그

#### EC2
- karpenter.sh/nodepool : 태그키가 존재하면 해당 EC2 는 karpenter 가 배포되지 않음
- kubernetes.io/cluster/{CLUSTER_NAME} 값이 "owned" 는 Self Managed 노드 임을 의미
- eks:eks-cluster-name 태그 값은 karpenter 가 EKS를 식별하는 클러스터 이름
- kubernetes.io/cluster/{CLUSTER_NAME} 태그 및 값 "owned"은 보안 그룹 태그에 대해선 반드시 하나의 EKS Primary 만 설정 해야 함. EC2, ELB, VPC 서브넷 등 클러스터에서 자동으로 리소스를 식별하고 관리하는데 사용


