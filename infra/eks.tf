# ==========================================
# 1. EKS Cluster IAM Role (Control Plane 권한)
# ==========================================
resource "aws_iam_role" "eks_cluster_role" {
  name = "bobpick-eks-cluster-role-3rd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# ==========================================
# 2. EKS Node Group IAM Role (워커 노드 권한)
# ==========================================
resource "aws_iam_role" "eks_node_role" {
  name = "bobpick-eks-node-role-3rd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_secrets_manager" {
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  role       = aws_iam_role.eks_node_role.name
}

# ==========================================
# 3. EKS Control Plane (클러스터 본체)
# ==========================================
resource "aws_eks_cluster" "main" {
  name     = "bobpick-eks-3rd"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31" # 최신 안정화 버전

  vpc_config {
    # 노드들이 배치될 프라이빗 서브넷 지정
    subnet_ids = [aws_subnet.private_app_a.id, aws_subnet.private_app_c.id]
    
    # 실무 보안 설정: 퍼블릭 접근을 열되, 추후 특정 IP만 허용하도록 제한 가능
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# ==========================================
# 4. EKS Managed Node Group (시작 템플릿 적용)
# ==========================================

# 4-1. EKS 1.31 버전에 맞는 최신 Amazon Linux 2 AMI 이미지 아이디 가져오기
data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/1.31/amazon-linux-2/recommended/image_id"
}

# 4-2. 시작 템플릿: Kubelet 파드 제한 강제 해제 스크립트 주입
resource "aws_launch_template" "eks_nodes_lt" {
  name_prefix   = "bobpick-node-lt-"
  image_id      = data.aws_ssm_parameter.eks_ami.value
  instance_type = "t3.micro"

  # 노드가 켜질 때 이 스크립트를 실행하여 파드 4개 제한을 17개로 늘립니다.
  user_data = base64encode(<<-EOF
#!/bin/bash
/etc/eks/bootstrap.sh ${aws_eks_cluster.main.name} \
  --use-max-pods false \
  --kubelet-extra-args '--max-pods=17'
EOF
  )
}

# 4-3. 워커 노드 그룹 생성 (시작 템플릿 적용)
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  
  # 기존과 이름이 충돌하지 않고 깔끔하게 교체되도록 -v2를 붙입니다.
  node_group_name = "bobpick-node-group-3rd-v2"
  
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.private_app_a.id, aws_subnet.private_app_c.id]

  # 기존 instance_types, ami_type 설정을 지우고 위에서 만든 시작 템플릿을 연결합니다.
  launch_template {
    id      = aws_launch_template.eks_nodes_lt.id
    version = "$Latest"
  }

  capacity_type  = "ON_DEMAND"

  # 노드 수 스케일링 설정
  scaling_config {
    desired_size = 8
    max_size     = 12
    min_size     = 8
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_readonly
  ]
}