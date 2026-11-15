# cloud-2026

REST API магазину (Flask + MySQL), розгорнутий в AWS: ECS Fargate за Application Load Balancer, RDS MySQL у приватних підмережах, образи в ECR, автодеплой з GitHub Actions через OIDC.

## Структура проєкту

<img width="828" height="868" alt="image" src="https://github.com/user-attachments/assets/81e9c8b8-0d57-42b6-a608-610dad2d5127" />

| Шлях | Що там |
|---|---|
| `database-ir-2025-lab4/` | Код застосунку і `Dockerfile` |
| `compose.yaml` | Локальний запуск застосунку разом з MySQL |
| `infra/` | Terraform: VPC, ECR, RDS, ECS, ALB, OIDC-роль, бюджет |
| `.github/workflows/deploy.yaml` | CI/CD: push у `main` → образ з тегом `github.sha` → оновлення ECS |

## Публічна адреса

http://myapp-alb-987737443.eu-central-1.elb.amazonaws.com/

Після кожного `terraform apply` адреса нова — її показує `terraform output app_url`.

## Локальний запуск

```bash
cp .env.example .env   # вказати свій DB_PASSWORD
docker compose up --build
curl localhost:8000/health
```

Дані MySQL зберігаються у volume `db_data` і переживають `docker compose down` (видаляються лише з `down -v`).

## Розгортання в AWS

`infra/terraform.tfvars` (у `.gitignore`):

```hcl
github_repo  = "SophiaBala/cloud-2026"
db_name      = "appdb"
db_username  = "appuser"
db_password  = "..."
budget_email = "you@example.com"
```

```bash
cd infra
terraform init
terraform apply      # також збирає і пушить початковий образ (потрібні docker і aws cli)
terraform output github_role_arn
```

ARN ролі записати в GitHub: Settings → Secrets and variables → Actions → Variables → `AWS_ROLE_ARN`.

Прибирання: `terraform destroy`.

## Архітектура і безпека

- Із інтернету доступний лише ALB (порт 80). Задачі ECS — у приватних підмережах без публічних IP; приймають трафік тільки від security group ALB.
- RDS — у приватних підмережах, `publicly_accessible = false`; приймає 3306 тільки від security group застосунку.
- NAT немає: задачі звертаються до ECR, S3 і CloudWatch Logs через VPC endpoints.
- Health check ALB — `GET /health`.
- Секрети не комітяться: пароль бази передається через `terraform.tfvars` / `.env` у змінні середовища контейнера.
- GitHub Actions отримує доступ до AWS через OIDC і роль `myapp-github`, обмежену гілкою `main` цього репозиторію; довговічних ключів немає.
