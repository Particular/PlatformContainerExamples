# particular-platform

Helm chart to install the Particular Platform components; a set of components that allows customer to monitor and manage errors on NServiceBus and MassTransit endpoints.

**Homepage:** <https://particular.net/>

## Before installing the chart

In order to use the particular-platform chart, you need the following infrastructure.

1. A RavenDB server
2. A broker connection string

We recommend install raven using our container [`particular/servicecontrol-ravendb`](https://hub.docker.com/r/particular/servicecontrol-ravendb).

## Installing the Chart

To install the chart just to have a look.
This setup creates a `test-particular-platform` namespace.

```shell
helm upgrade --install --generate-name --create-namespace --namespace test-particular-platform .
```

To install the chart on a production environment.
This setup creates a `particular-platform` namespace and adds the license to the chart and also references an extra values override file for extra customization.

```shell
helm upgrade --install --generate-name --create-namespace --namespace particular-platform -f <path to values overrides yaml file> --set-file licenseData=<path to license file>/license.xml .
```

Example of a values_override.yaml file

```yaml
transport:
  # the connection string to connect to the broker, see https://docs.particular.net/servicecontrol/transports
  connectionString: "host=my-rabbit;virtualhost=k8s;"
  # the broker type, see https://docs.particular.net/servicecontrol/transports
  type: "RabbitMQ.QuorumConventionalRouting"

ravenDBUrl: "http://my-ravendb:8080"

audit:
  # the number of audit instances to provision
  instances: 2

pulse:
  service:
    # The type of service to create
    type: "LoadBalancer"
```
