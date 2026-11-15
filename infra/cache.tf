resource "aws_elasticache_subnet_group" "cache" {
  name       = "${var.project}-cache"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_replication_group" "cache" {
  replication_group_id       = "${var.project}-cache"
  description                = "Read cache for ${var.project}"
  engine                     = "valkey"
  engine_version             = "8.0"
  node_type                  = "cache.t4g.micro"
  num_cache_clusters         = 1
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.cache.name
  security_group_ids         = [aws_security_group.cache.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  automatic_failover_enabled = false
  apply_immediately          = true
}
