# ==========================================
# 1. EKS OIDC Provider (지문 인식기 설치)
# ==========================================
# EKS 클러스터의 인증서 정보를 가져옵니다.
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# AWS IAM에 EKS용 OIDC(지문 인식기)를 등록합니다.
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ==========================================
# 2. 밥픽 앱 Pod용 S3 접근 권한 (IRSA)
# ==========================================
# 파드가 S3에 접근할 수 있도록 해주는 신분증(IAM Role)입니다.
resource "aws_iam_role" "app_pod_s3_role" {
  name = "bobpick-app-pod-s3-role-3rd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # 나중에 쿠버네티스에서 만들 'bobpick-app-sa'라는 서비스 어카운트만 이 권한을 쓸 수 있음
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:default:bobpick-app-sa"
        }
      }
    }]
  })
}

# S3에 접근할 수 있는 정책을 신분증에 부여합니다.
resource "aws_iam_role_policy_attachment" "app_pod_s3_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # 필요에 따라 권한 축소 가능
  role       = aws_iam_role.app_pod_s3_role.name
}

# ==========================================
# 3. AWS Load Balancer Controller용 IRSA
# ==========================================
# 다운로드 받은 JSON 파일로 IAM 정책 생성
resource "aws_iam_policy" "albc_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy-3rd"
  policy = file("iam_policy.json")
}

# ALB 로봇이 사용할 IAM 역할(신분증) 생성
resource "aws_iam_role" "albc_role" {
  name = "bobpick-albc-role-3rd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # kube-system 공간에 설치될 aws-load-balancer-controller만 이 신분증을 쓸 수 있음
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# 역할(신분증)에 정책(권한) 연결
resource "aws_iam_role_policy_attachment" "albc_policy_attach" {
  policy_arn = aws_iam_policy.albc_policy.arn
  role       = aws_iam_role.albc_role.name
}