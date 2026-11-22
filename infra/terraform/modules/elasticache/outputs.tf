output "endpoint" {
  description = "Endpoint do cluster Redis"
  value       = aws_elasticache_cluster.this.cache_nodes[0].address
}

output "port" {
  description = "Porta do cluster Redis"
  value       = aws_elasticache_cluster.this.port
}
