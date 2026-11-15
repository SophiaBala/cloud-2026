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

Скопіюйте `.env.example` у `.env` і вкажіть у ньому свій `DB_PASSWORD`:

```bash
cp .env.example .env
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
terraform apply
terraform output github_role_arn
```

`terraform apply` також збирає і пушить початковий образ, тому локально потрібні `docker` і `aws` CLI.

ARN ролі записати в GitHub: Settings → Secrets and variables → Actions → Variables → `AWS_ROLE_ARN`.

Прибирання: `terraform destroy`.

## Архітектура і безпека

- Із інтернету доступний лише ALB (порт 80). Задачі ECS — у приватних підмережах без публічних IP; приймають трафік тільки від security group ALB.
- RDS — у приватних підмережах, `publicly_accessible = false`; приймає 3306 тільки від security group застосунку.
- NAT немає: задачі звертаються до ECR, S3 і CloudWatch Logs через VPC endpoints.
- Health check ALB — `GET /health`.
- Секрети не комітяться: пароль бази передається через `terraform.tfvars` / `.env` у змінні середовища контейнера.
- GitHub Actions отримує доступ до AWS через OIDC і роль `myapp-github`, обмежену гілкою `main` цього репозиторію; довговічних ключів немає.

## Лабораторна 2: масштабування, моніторинг, кеш

| Що | Код | Документ |
|---|---|---|
| Автомасштабування ECS за CPU (1–4 задачі, ціль 60 %) | `infra/autoscaling.tf` | [docs/AUTOSCALING.md](docs/AUTOSCALING.md) |
| Сценарій k6 «1 запис + 9 читань» | `loadtest/` | [docs/LOADTEST.md](docs/LOADTEST.md) |
| Панель CloudWatch (`terraform output dashboard_url`) | `infra/monitoring.tf` | [docs/AUTOSCALING.md](docs/AUTOSCALING.md) |
| Аларм CPU > 70 % 2 хв → email (ALARM і OK) | `infra/monitoring.tf` | [docs/ALERTS.md](docs/ALERTS.md) |
| Cache-aside для `GET /shop` на ElastiCache (Valkey) | `infra/cache.tf`, `my_project/cache.py` | [docs/CACHE.md](docs/CACHE.md) |

| Бонус: черга SQS + обробник, що масштабується від 0 до 4 | `infra/sqs.tf`, `infra/worker.tf`, `worker.py` | [docs/QUEUE.md](docs/QUEUE.md) |
| Бонус: `Idempotency-Key` для записів | `my_project/idempotency.py`, `tests/` | [docs/IDEMPOTENCY.md](docs/IDEMPOTENCY.md) |
| Бонус: розклад, удень мінімум 2 задачі, уночі 1 | `infra/schedule.tf` | [docs/SCHEDULE.md](docs/SCHEDULE.md) |

Нові ендпоінти: `GET /shop?limit=N` (останні N, за замовчуванням 50, кешується), `GET /shop/{id}`, `GET /shop/{id}/staff`, `GET /stats` (лічильники запитів MySQL і влучань у кеш для звітів), `POST /shop/async` (202, запис через чергу), `GET /jobs/{id}` (статус асинхронної задачі). `POST /shop` і `POST /shop/async` приймають заголовок `Idempotency-Key`.

Додаткові змінні в `terraform.tfvars` (необов'язкові): `alert_email`, `cache_enabled`, `cache_ttl_seconds`, `cpu_target`.
