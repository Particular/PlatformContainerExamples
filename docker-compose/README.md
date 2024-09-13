# Running with Docker Compose

This [Docker Compose](https://docs.docker.com/compose/) file provides an example of spinning up [ServiceControl](https://docs.particular.net/servicecontrol/) and [ServicePulse](https://docs.particular.net/servicepulse/) in a local development environment, using a container-hosted [RabbitMQ](https://docs.particular.net/transports/rabbitmq/) broker as the message transport.

Running ServiceControl and ServicePulse locally in containers provides a way to use and test Service Platform features during local development on any platform, without needing to install Windows services.

## Usage

 **Pull the Latest Images:** Before running the containers, ensure you're using the latest version of each image by executing the following command:
 ```shell
 docker compose pull
 ```
 This command checks for any updates to the images specified in your docker-compose.yml file and pulls them if available.

**Start the Containers:** After pulling the latest images, modify the [environment file](.env), if necessary, and then start up the containers using:
```shell
docker compose up -d
```

Once composed:

* [ServicePulse](https://docs.particular.net/servicepulse/) can be accessed at http://localhost:9090
* [ServiceInsight](https://docs.particular.net/serviceinsight/) can be used with a connection URL of http://localhost:33333/api

## Implementation details

* The ports for all services are exposed to localhost:
  * `33333`: ServiceControl API
  * `44444`: Audit API
  * `33633`: Monitoring API
  * `8080`: Database backend
  * `9090` ServiceInsight UI
* Volumes are mapped to directories in `./volumes/*`.
* One instance of the [`servicecontrol-ravendb` container](https://docs.particular.net/servicecontrol/ravendb/containers) is used for both the [`servicecontrol`](https://docs.particular.net/servicecontrol/servicecontrol-instances/deployment/containers) and [`servicecontrol-audit`](https://docs.particular.net/servicecontrol/audit-instances/deployment/containers) containers.
  * _A single database container should not be shared between multiple ServiceControl instances in production scenarios._
