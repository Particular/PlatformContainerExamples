# Running with Terraform

This [Terraform](https://www.terraform.io/) configuration provides an example of spinning up [ServiceControl](https://docs.particular.net/servicecontrol/) and [ServicePulse](https://docs.particular.net/servicepulse/) in a local development environment, using a container-hosted [RabbitMQ](https://docs.particular.net/transports/rabbitmq/) broker as the message transport.

Running ServiceControl and ServicePulse locally in containers provides a way to use and test Service Platform features during local development on any platform, without needing to install Windows services.

## Prerequisites

1. [Docker](https://docs.docker.com/get-docker/) installed and running
2. [Terraform](https://www.terraform.io/downloads) (version 1.0 or later) installed

## Usage

### Initialize Terraform

Before running Terraform for the first time, initialize the working directory to download the required provider plugins:

```shell
terraform init
```

### Configure variables (optional)

You can customize the deployment by creating a `terraform.tfvars` file. An example file is provided:

```shell
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferred settings
```

Key variables you might want to customize:
- `servicecontrol_tag`: Version tag for ServiceControl images (default: `latest`)
- `servicepulse_tag`: Version tag for ServicePulse image (default: `latest`)
- `transport_type`: Message transport type (default: `RabbitMQ.QuorumConventionalRouting`)
- `connection_string`: Transport connection string
- `particular_license`: Your Particular Software license (optional, uses trial if not provided)

### Deploy the infrastructure

To see what Terraform will create:

```shell
terraform plan
```

To deploy the containers:

```shell
terraform apply
```

Terraform will show you the planned changes and ask for confirmation. Type `yes` to proceed.

### Access the services

Once deployed, the following services will be available:

* [ServicePulse](https://docs.particular.net/servicepulse/) at http://localhost:9090
* [ServiceInsight](https://docs.particular.net/serviceinsight/) can connect to http://localhost:33333/api
* RabbitMQ Management UI at http://localhost:15672 (credentials: `guest`/`guest`)

To see all output URLs, run:

```shell
terraform output
```

### Destroy the infrastructure

To stop and remove all containers and resources:

```shell
terraform destroy
```

Type `yes` when prompted to confirm the destruction.

## Implementation details

* The ports for all services are exposed to localhost:
  * `33333`: ServiceControl API
  * `44444`: Audit API
  * `33633`: Monitoring API
  * `8080`: RavenDB backend
  * `9090`: ServicePulse UI
  * `5672`: RabbitMQ AMQP
  * `15672`: RabbitMQ Management UI
* All containers are connected via a dedicated Docker network (`service-platform-network`)
* Persistent Docker volumes are created for:
  * RabbitMQ data
  * RavenDB configuration
  * RavenDB data
* One instance of the [`servicecontrol-ravendb` container](https://docs.particular.net/servicecontrol/ravendb/containers) is used for both the [`servicecontrol`](https://docs.particular.net/servicecontrol/servicecontrol-instances/deployment/containers) and [`servicecontrol-audit`](https://docs.particular.net/servicecontrol/audit-instances/deployment/containers) containers.
  * _A single database container should not be shared between multiple ServiceControl instances in production scenarios._
* The configuration uses the [Terraform Docker provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs) to manage containers locally

## Advanced configuration

### Using a different transport

To use a different message transport, modify the `transport_type` and `connection_string` variables in your `terraform.tfvars` file. See the [ServiceControl Transports documentation](https://docs.particular.net/servicecontrol/transports) for supported transport types and connection string formats.

### Remote Docker daemon

To deploy to a remote Docker daemon, set the `docker_host` variable:

```hcl
docker_host = "tcp://remote-host:2376"
```

### Custom port mappings

All external ports can be customized via variables. For example, to change the ServicePulse port:

```hcl
servicepulse_port = 8080
```

## Troubleshooting

### Viewing container logs

To view logs for a specific container:

```shell
docker logs servicecontrol
docker logs servicecontrol-audit
docker logs servicecontrol-monitoring
docker logs servicepulse
docker logs rabbitmq
docker logs servicecontrol-db
```

### Inspecting Terraform state

To see the current state of resources:

```shell
terraform show
```

### Force recreation of a container

If a container is misbehaving, you can force Terraform to recreate it:

```shell
terraform taint docker_container.servicecontrol
terraform apply
```

Replace `servicecontrol` with any other container name as needed.
