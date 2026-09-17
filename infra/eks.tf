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
# 4. EKS Managed Node Group (워커 노드 그룹)
# ==========================================
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "bobpick-node-group-3rd"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.private_app_a.id, aws_subnet.private_app_c.id]

  # 우리가 결정한 인스턴스 타입
  instance_types = ["t3.micro"]
  capacity_type  = "ON_DEMAND"
  ami_type       = "AL2_x86_64"
  version        = "1.31"

  # 노드 수 스케일링 설정
  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
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