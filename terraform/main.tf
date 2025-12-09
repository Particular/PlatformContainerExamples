terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

# Create a Docker network for the service platform
resource "docker_network" "service_platform" {
  name = "service-platform-network"
}

# Create volumes for persistent data
resource "docker_volume" "rabbitmq_data" {
  name = "service-platform-rabbitmq-data"
}

resource "docker_volume" "raven_config" {
  name = "service-platform-raven-config"
}

resource "docker_volume" "raven_data" {
  name = "service-platform-raven-data"
}

# RabbitMQ container
resource "docker_image" "rabbitmq" {
  name = "rabbitmq:3-management"
}

resource "docker_container" "rabbitmq" {
  name  = "rabbitmq"
  image = docker_image.rabbitmq.image_id

  networks_advanced {
    name = docker_network.service_platform.name
  }

  ports {
    internal = 5672
    external = var.rabbitmq_port
  }

  ports {
    internal = 15672
    external = var.rabbitmq_management_port
  }

  volumes {
    volume_name    = docker_volume.rabbitmq_data.name
    container_path = "/var/lib/rabbitmq"
  }

  restart = "unless-stopped"

  healthcheck {
    test     = ["CMD", "rabbitmq-diagnostics", "check_port_connectivity"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# ServiceControl RavenDB container
resource "docker_image" "servicecontrol_ravendb" {
  name = "particular/servicecontrol-ravendb:${var.servicecontrol_tag}"
}

resource "docker_container" "servicecontrol_db" {
  name  = "servicecontrol-db"
  image = docker_image.servicecontrol_ravendb.image_id

  networks_advanced {
    name = docker_network.service_platform.name
  }

  ports {
    internal = 8080
    external = var.ravendb_port
  }

  volumes {
    volume_name    = docker_volume.raven_config.name
    container_path = "/var/lib/ravendb/config"
  }

  volumes {
    volume_name    = docker_volume.raven_data.name
    container_path = "/var/lib/ravendb/data"
  }

  restart = "unless-stopped"

  healthcheck {
    test     = ["CMD-SHELL", "/usr/lib/ravendb/scripts/healthcheck.sh"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# ServiceControl (Error instance) container
resource "docker_image" "servicecontrol" {
  name = "particular/servicecontrol:${var.servicecontrol_tag}"
}

resource "docker_container" "servicecontrol" {
  name  = "servicecontrol"
  image = docker_image.servicecontrol.image_id

  networks_advanced {
    name = docker_network.service_platform.name
  }

  ports {
    internal = 33333
    external = var.servicecontrol_port
  }

  env = [
    "RAVENDB_CONNECTIONSTRING=http://servicecontrol-db:8080",
    "REMOTEINSTANCES=[{\"api_uri\":\"http://servicecontrol-audit:44444/api\"}]",
    "TRANSPORTTYPE=${var.transport_type}",
    "CONNECTIONSTRING=${var.connection_string}",
    "PARTICULARSOFTWARE_LICENSE=${var.particular_license}"
  ]

  command = ["--setup-and-run"]

  restart = "unless-stopped"

  depends_on = [
    docker_container.servicecontrol_db,
    docker_container.rabbitmq
  ]
}

# ServiceControl Audit container
resource "docker_image" "servicecontrol_audit" {
  name = "particular/servicecontrol-audit:${var.servicecontrol_tag}"
}

resource "docker_container" "servicecontrol_audit" {
  name  = "servicecontrol-audit"
  image = docker_image.servicecontrol_audit.image_id

  networks_advanced {
    name = docker_network.service_platform.name
  }

  ports {
    internal = 44444
    external = var.servicecontrol_audit_port
  }

  env = [
    "RAVENDB_CONNECTIONSTRING=http://servicecontrol-db:8080",
    "SERVICECONTROLQUEUEADDRESS=Particular.ServiceControl",
    "TRANSPORTTYPE=${var.transport_type}",
    "CONNECTIONSTRING=${var.connection_string}",
    "PARTICULARSOFTWARE_LICENSE=${var.particular_license}"
  ]

  command = ["--setup-and-run"]

  restart = "unless-stopped"

  depends_on = [
    docker_container.servicecontrol_db,
    docker_container.rabbitmq
  ]
}

# ServiceControl Monitoring container
resource "docker_image" "servicecontrol_monitoring" {
  name = "particular/servicecontrol-monitoring:${var.servicecontrol_tag}"
}

resource "docker_container" "servicecontrol_monitoring" {
  name  = "servicecontrol-monitoring"
  image = docker_image.servicecontrol_monitoring.image_id

  networks_advanced {
    name = docker_network.service_platform.name
  }

  ports {
    internal = 33633
    external = var.servicecontrol_monitoring_port
  }

  env = [
    "TRANSPORTTYPE=${var.transport_type}",
    "CONNECTIONSTRING=${var.connection_string}",
    "PARTICULARSOFTWARE_LICENSE=${var.particular_license}"
  ]

  command = ["--setup-and-run"]

  restart = "unless-stopped"

  depends_on = [
    docker_container.rabbitmq
  ]
}

# ServicePulse container
resource "docker_image" "servicepulse" {
  name = "particular/servicepulse:${var.servicepulse_tag}"
}

resource "docker_container" "servicepulse" {
  name  = "servicepulse"
  image = docker_image.servicepulse.image_id

  networks_advanced {
    name = docker_network.service_platform.name
  }

  ports {
    internal = 9090
    external = var.servicepulse_port
  }

  env = [
    "SERVICECONTROL_URL=http://servicecontrol:33333",
    "MONITORING_URL=http://servicecontrol-monitoring:33633"
  ]

  restart = "unless-stopped"

  depends_on = [
    docker_container.servicecontrol,
    docker_container.servicecontrol_monitoring,
    docker_container.rabbitmq
  ]
}
