resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project}-db-password"
  recovery_window_in_days = 0 # щоб terraform destroy прибирав без залишку
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = random_password.db.result
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.project}-db"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "db" {
  identifier             = "${var.project}-db"
  engine                 = "mysql"
  engine_version         = "8.4"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  db_name                = "appdb"
  username               = "appadmin"
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}