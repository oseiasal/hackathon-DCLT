variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, prod)"
  type        = string
}

variable "queue_name" {
  description = "Nome da fila SQS principal"
  type        = string
  default     = "solidary-donations"
}

variable "visibility_timeout_seconds" {
  description = "Tempo de visibilidade da mensagem em segundos"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Retenção de mensagens em segundos (default 4 dias)"
  type        = number
  default     = 345600
}

variable "max_receive_count" {
  description = "Tentativas antes de enviar a mensagem para a DLQ"
  type        = number
  default     = 5
}
