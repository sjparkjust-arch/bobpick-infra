# 1. 최신 Ubuntu 24.04 AMI(운영체제 이미지)를 자동으로 찾아주는 코드
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu 공식 배포자 ID)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# 2. 징검다리 및 검증용 EC2 인스턴스 생성
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.private_app_a.id
  vpc_security_group_ids = [aws_security_group.app.id]

  key_name = "mysite-key"

  tags = {
    Name = "${var.environment}-base-ec2"
  }
}

# 3. 퍼블릭 서브넷에 위치할 베스천 호스트 EC2 생성
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.public_c.id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  key_name                    = "mysite-key"
  associate_public_ip_address = true

  tags = {
    Name = "bobpick-public-bastion"
  }
}

# 4. 베스천 호스트 퍼블릭 IP 화면 출력
output "bastion_public_ip" {
  description = "베스천 호스트 접속용 퍼블릭 IP"
  value       = aws_instance.bastion.public_ip
}
