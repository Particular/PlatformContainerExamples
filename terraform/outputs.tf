output "servicepulse_url" {
  description = "URL for ServicePulse web interface"
  value       = "http://localhost:${var.servicepulse_port}"
}

output "servicecontrol_api_url" {
  description = "URL for ServiceControl API (for use with ServiceInsight)"
  value       = "http://localhost:${var.servicecontrol_port}/api"
}

output "servicecontrol_audit_api_url" {
  description = "URL for ServiceControl Audit API"
  value       = "http://localhost:${var.servicecontrol_audit_port}/api"
}

output "servicecontrol_monitoring_url" {
  description = "URL for ServiceControl Monitoring API"
  value       = "http://localhost:${var.servicecontrol_monitoring_port}"
}

output "ravendb_url" {
  description = "URL for RavenDB management interface"
  value       = "http://localhost:${var.ravendb_port}"
}

output "rabbitmq_management_url" {
  description = "URL for RabbitMQ Management UI (credentials: guest/guest)"
  value       = "http://localhost:${var.rabbitmq_management_port}"
}

output "network_name" {
  description = "Name of the Docker network created for the service platform"
  value       = docker_network.service_platform.name
}
