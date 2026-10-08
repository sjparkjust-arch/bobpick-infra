# bobpick-infra · 밥픽 AWS 인프라 (Terraform)

> 온프레미스에서 운영하던 밥픽 서비스를 AWS로 옮기기 위한 Terraform 코드입니다.
> **`main` 브랜치는 2차(EC2 + Auto Scaling)**, **`3rd/eks-han` 브랜치는 3차(Amazon EKS)** 인프라입니다.

| 브랜치 | 단계 | 구성 | 담당 |
|---|---|---|---|
| `main` (현재) | 2차 · 2026.08.20 ~ 09.15 | VPC, ALB, WAF, Auto Scaling Group, RDS, ElastiCache, S3·CloudFront | 공동 ([역할 분담](#역할-분담-2차)) |
| [`3rd/eks-han`](https://github.com/sjparkjust-arch/bobpick-infra/tree/3rd/eks-han) | 3차 · 2026.09.14 ~ 10.07 | EKS, IRSA, ECR, Secrets Manager | 최한빈 |

- 프로젝트 전체 소개와 앱 코드: [menu-recommend](https://github.com/sjparkjust-arch/menu-recommend)
- 3차 쿠버네티스 매니페스트: [bobpick-manifests](https://github.com/sjparkjust-arch/bobpick-manifests)

> 프로젝트 종료 후 AWS 리소스는 `terraform destroy`로 모두 삭제했습니다.

<br>

## 2차 아키텍처

- **요청**: 사용자 → Route 53 → WAF → ALB(HTTPS) → Auto Scaling Group 앱 서버 2~4대 → RDS MySQL(Multi-AZ) · ElastiCache Redis
- **정적 파일**: CloudFront(OAC) → S3
- **네트워크**: VPC `10.0.0.0/16`, 가용 영역 2개(2a, 2c), 서브넷 6개 (퍼블릭 · 프라이빗 앱 · 프라이빗 DB)
- **관리 접근**: 퍼블릭 서브넷의 Bastion, Systems Manager

### 설계 포인트

- **가용 영역 2개, 서브넷 6개**: 퍼블릭(ALB·NAT·Bastion), 프라이빗 앱, 프라이빗 DB를 AZ마다 하나씩 두어, ALB·앱 서버·DB가 한 AZ 장애에도 이어지게 했습니다. (Redis는 단일 노드)
- **NAT Gateway를 AZ마다 하나씩**: 프라이빗 서브넷은 같은 AZ의 NAT로 나가게 라우팅해, NAT 하나가 단일 장애점이 되지 않게 했습니다.
- **보안 그룹 계층화**: 인터넷 → ALB(80/443) → 앱(8000은 ALB에서만, SSH는 Bastion에서만) → DB(3306·6379, 앱·Bastion에서만). Bastion SSH는 지정한 IP에서만 허용합니다.
- **입구 보호**: WAF에 AWS 관리형 규칙(Common Rule Set, IP 평판 목록)과 5분당 2,000회 요청 제한을 걸었고, ACM 인증서로 HTTPS를 적용했습니다.
- **DB 이중화**: RDS는 Multi-AZ로 구성해, 1차에서 DB 서버 한 대가 서비스 전체의 단일 장애점이던 구조를 바꿨습니다.

<br>

## 파일 구성

| 파일 | 내용 |
|---|---|
| `infra/network.tf` | VPC, 서브넷 6개 (퍼블릭 `10.0.1·2.0/24`, 프라이빗 앱 `10.0.10·20.0/24`, 프라이빗 DB `10.0.100·200.0/24`) |
| `infra/gateway.tf` | 인터넷 게이트웨이, AZ별 NAT Gateway 2개, 라우팅 테이블 |
| `infra/security.tf` | 보안 그룹 4개 (ALB, 앱, Bastion, DB) |
| `infra/alb.tf` | ALB, 타겟 그룹 (헬스체크, 새 서버에 60초간 트래픽을 천천히 넣는 slow_start) |
| `infra/dns-tls.tf` | Route 53 호스팅 영역, ACM 인증서, HTTPS 리스너, HTTP→HTTPS 리다이렉트 |
| `infra/waf.tf` | WAF 웹 ACL (관리형 규칙 2개 + 요청 수 제한) |
| `infra/asg.tf` | 시작 템플릿(user_data, 상세 모니터링), ASG 최소 2 · 최대 4대, CPU 40% 목표 추적 정책 |
| `infra/rds.tf` · `infra/redis.tf` | RDS MySQL 8.0 Multi-AZ, ElastiCache Redis (세션·캐시) |
| `infra/s3.tf` · `infra/s3-iam.tf` | S3(암호화, 퍼블릭 차단) + CloudFront(OAC, CORS 응답 헤더 정책), 앱 서버 IAM 역할 |
| `infra/ec2.tf` · `infra/ssm.tf` | Bastion, Systems Manager 접속 권한 |
| `infra/cloudwatch.tf` | CPU, 5xx 에러, 정상 서버 수 알람 → SNS 메일 |
| `bootstrap/` | Terraform 상태 저장용 S3 버킷(버전 관리, 암호화) + DynamoDB 잠금 테이블 |
| `.github/workflows/terraform.yml` | 인프라 CI/CD |
| `docs/` | 계정 이관, 부하테스트 상세 기록 |

<br>

## 인프라 CI/CD

`infra/` 아래 코드가 바뀌면 GitHub Actions가 자동으로 검사하고 적용합니다.

```
Pull Request / push  →  fmt 검사  →  init  →  validate  →  plan  →  apply (main에 push될 때만)
```

- 상태 파일은 S3 원격 백엔드에 두고 DynamoDB로 잠가, 두 사람이 동시에 적용해도 상태가 꼬이지 않게 했습니다.
- AWS 자격 증명과 DB 비밀번호는 GitHub Secrets로 주입하고, 코드에는 비밀번호를 두지 않았습니다.

<br>

## 역할 분담 (2차)

| | 담당 |
|---|---|
| **박상준** (Infra) | VPC·서브넷·NAT·라우팅·보안 그룹, ALB, WAF, ACM·HTTPS·Route 53, Terraform CI 파이프라인, 팀원 코드 병합(하드코딩된 리소스 ID를 참조로 교체), CloudFront CORS 응답 헤더 정책 연결, user_data 코드화, 계정 이관(9/14), 부하테스트와 개선 |
| **최한빈** (App) | RDS(Multi-AZ 전환), ElastiCache, 시작 템플릿·ASG, S3·CloudFront, CloudWatch 알람, 앱 배포 파이프라인 |
| **공동** | 팀원 계정으로의 첫 번째 이관(8/28) |

<br>

## 2차 결과

자세한 과정은 [docs/00_요약.md](docs/00_요약.md), [docs/01_AWS계정이관.md](docs/01_AWS계정이관.md), [docs/02_부하테스트.md](docs/02_부하테스트.md)에 정리했습니다.

### 부하테스트 (JMeter)

| 차수 | 조건 | 처리량 | 평균 응답 | 에러율 |
|---|---|---|---|---|
| 1차 기준선 | 10명 / 서버 2대 | 14.79 TPS | 93ms | 0% |
| 2차 증설 | 100명 / 2→4대 | 87 TPS | 600ms | 502 에러 40건 |
| 3차 개선 검증 | 100명 / 2→4대 | 87 TPS | 595ms | **0.00%** |
| 4차 한계치 | 300명 / 4대 | 74 TPS | 3,495ms | 0.01% |
| 5차 축소 | 10명 / 4→2대 | 15.51 TPS | 92ms | 0.00% |

### 찾아서 고친 문제

| 문제 | 원인 | 조치 |
|---|---|---|
| CPU가 90%를 넘어도 서버가 늘지 않음 | ① ASG에 확장 정책이 없었음 ② 알람은 1분 단위 데이터를 요구하는데 EC2 기본 모니터링은 5분 간격 | CPU 40% 목표 추적 정책 추가, 시작 템플릿에 상세 모니터링 활성화 |
| 서버가 늘어나는 구간에 502 에러 40건 (해당 30초 구간 에러율 1.91%) | 새 서버가 헬스체크를 통과해 요청을 받기 시작한 뒤, user_data가 Gunicorn을 재시작해 연결이 끊김 | Gunicorn `ExecReload`로 무중단 재시작, user_data의 restart를 reload로 변경, user_data에서 migrate·collectstatic 제거, 타겟 그룹 `slow_start` 60초 → **재측정 502 에러 0건** |
| WAF 요청 제한에 테스트 트래픽이 걸릴 수 있음 (테스트 전 코드 점검에서 발견) | 5분당 2,000회는 가장 가벼운 테스트보다 낮은 값 | 테스트 IP만 한시적으로 예외 처리하고 종료 후 제거 |

### 계정 이관 (9/14)

- 리소스 63개를 약 3시간 만에 새 계정에 다시 구축
- 코드로 재현되지 않는 항목(AMI, 키페어, 도메인 위임, DB 데이터, 버킷 이름)을 먼저 목록으로 만들어 처리
- `terraform plan` 결과에서 의도하지 않은 DB 비밀번호 변경을 발견해 적용 전에 멈춤

<br>

## 2차에서 찾은 과제와 3차 반영

| 2차에서 찾은 과제 | 3차에서 바꾼 것 |
|---|---|
| 헬스체크가 추천 로직이 도는 메인 페이지(`/`)를 호출해, 부하 시 헬스체크부터 실패 | DB 연결만 확인하는 `/healthz/`를 앱에 추가 |
| 서버마다 migrate·collectstatic이 중복 실행 | 파드 수와 관계없이 한 번만 실행되는 migrate Job |
| 앱 배포에 장기 액세스 키 사용 | 앱 배포는 GitHub OIDC 임시 자격 증명 |
| 서버 단위 확장 (증설에 4~6분) | 파드 단위 확장 (30~80초) + 노드 자동 확장 |

<br>

## 3차 브랜치 (`3rd/eks-han`)

3차 EKS 인프라는 팀원(최한빈)이 이 브랜치에서 작업했고, `main`에는 병합하지 않았습니다.

- EKS 1.31, 관리형 노드 그룹 (시작 템플릿으로 노드당 파드 수 상한 조정), 노드 8~12대
- IRSA: 앱 파드(S3), AWS Load Balancer Controller용 IAM 역할
- ECR, RDS·Redis·S3·CloudFront, Secrets Manager(앱 설정 값 저장) + External Secrets Operator
- 클러스터에 설치한 구성 요소의 설정 파일 (External Secrets Operator 차트, Prometheus·Grafana values, Cluster Autoscaler·ALB Controller용 IAM 정책)

앱 배포 쪽(매니페스트, Argo CD, HPA)은 [bobpick-manifests](https://github.com/sjparkjust-arch/bobpick-manifests)를 참고해 주세요.
