output "queue_url" {
  description = "URL da fila SQS principal"
  value       = aws_sqs_queue.this.url
}

output "queue_arn" {
  description = "ARN da fila SQS principal"
  value       = aws_sqs_queue.this.arn
}

output "dlq_url" {
  description = "URL da Dead-Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN da Dead-Letter Queue"
  value       = aws_sqs_queue.dlq.arn
}
