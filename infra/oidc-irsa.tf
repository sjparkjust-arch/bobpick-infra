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