variable "docker_host" {
  description = "Docker daemon host (e.g., unix:///var/run/docker.sock for local, or tcp://host:2376 for remote)"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "servicecontrol_tag" {
  description = "Docker image tag for ServiceControl components"
  type        = string
  default     = "latest"
}

variable "servicepulse_tag" {
  description = "Docker image tag for ServicePulse"
  type        = string
  default     = "latest"
}

variable "transport_type" {
  description = "The message transport type (e.g., RabbitMQ.QuorumConventionalRouting)"
  type        = string
  default     = "RabbitMQ.QuorumConventionalRouting"
}

variable "connection_string" {
  description = "Connection string for the message transport"
  type        = string
  default     = "host=rabbitmq;username=guest;password=guest"
}

variable "particular_license" {
  description = <<-EOT
    Particular Software license content (optional, will use trial if not provided).
    Should contain the full XML content of the license file.
    Example format:
    <?xml version="1.0" encoding="utf-8"?>
    <license id="..." expiration="..." type="...">
      ...
    </license>
  EOT
  type        = string
  default     = ""
  sensitive   = true
}

variable "servicecontrol_port" {
  description = "External port for ServiceControl API"
  type        = number
  default     = 33333
}

variable "servicecontrol_audit_port" {
  description = "External port for ServiceControl Audit API"
  type        = number
  default     = 44444
}

variable "servicecontrol_monitoring_port" {
  description = "External port for ServiceControl Monitoring API"
  type        = number
  default     = 33633
}

variable "servicepulse_port" {
  description = "External port for ServicePulse UI"
  type        = number
  default     = 9090
}

variable "ravendb_port" {
  description = "External port for RavenDB"
  type        = number
  default     = 8080
}

variable "rabbitmq_port" {
  description = "External port for RabbitMQ AMQP"
  type        = number
  default     = 5672
}

variable "rabbitmq_management_port" {
  description = "External port for RabbitMQ Management UI"
  type        = number
  default     = 15672
}
