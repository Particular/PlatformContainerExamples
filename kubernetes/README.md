# Deploying to Kubernetes

This set of yaml files provide an example of deploying ServiceControl and ServicePulse to a Kubernetes cluster.

This can be used as a starting point for a Kubernetes deployment, but should not be used as-is.

## Usage using Minikube

```bash
minikube start --memory=12Gb

minikube addons enable ingress

## Create a namespace (particular-platform-example)
kubectl apply -f namespace.yaml

## Apply a single instance RabbitMQ cluster by applying and using the RabbitMQ cluster operator
kubectl apply -f https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml
kubectl apply -f rabbitmqcluster.yaml

## Apply ServiceControl monitoring instance as a Deployment
kubectl apply -f servicecontrol-monitoring.deployment.yaml

## Apply a ServiceControl auditing instance as a StatefulSet
kubectl apply -f servicecontrol-audit.statefulset.yaml

## Apply a ServiceControl error instance as a StatefulSet
kubectl apply -f servicecontrol-error.statefulset.yaml

## Apply ServicePulse as a Deployment
kubectl apply -f servicepulse.deployment.yaml

## Apply an ingress to expose ServicePulse
kubectl apply -f ingress.yaml

## Destroy the minikube cluster when you are done
minikube delete
```

## Implementation details

This example was created and tested using [Minikube-in-Docker](https://github.com/devcontainers/templates/tree/main/src/kubernetes-helm-minikube) dev container. 

### Namespace

All of the resources in this example are applied to the `particular-platform-example` namespace.

### RabbitMQ

RabbitMQ, using conventional routing and quorum queues is used as the transport in this example. The RabbitMQ instance is deployed to the cluster using the [RabbitMQ Kubernetes Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview). The default host, user, and password secrets created by the operator are used to generate [the transport connection string](https://docs.particular.net/transports/rabbitmq/connection-settings#transport-layer-security-support) using a [dependent environment variable](https://kubernetes.io/docs/tasks/inject-data-application/define-interdependent-environment-variables/).

### ServiceControl Error and ServiceControl Audit

ServiceControl Error and ServiceControl Audit are deployed as [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/), with the RavenDB instance deployed as [a sidecar container](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) backed by a [Persistent Volume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/). The error or auditing images are also run as [an init container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) with the `--setup` command line argument. This would allow the init to run with higher priviledges than the regular application container, but this is not demonstrated in this example. 

### Monitoring

ServiceControl Monitoring is deployed as a [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) as it is a stateless application. The monitoring image is also run as [an init container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) with the `--setup` command line argument.

### Services

ServiceControl Error, ServiceControl Audit, ServiceControl Monitoring, and ServicePulse all have associated [Services](https://kubernetes.io/docs/concepts/services-networking/service/):

- The service associated with the error instance allows service discovery by ServicePulse as well as allowing the RavenDB console to be exposed by the ingress.
- The service associated with the audit instance allows service discovery by the error instances as well as allowing the RavenDB console to be exposed by the ingress.
- The service associated with the monitoring instances allows service discovery by ServicePulse.
- The service associated with ServicePulse allows ServicePulse to be exposed by the ingress.

### Ingress

The ingress uses the [`Ingress-Nginx` controller](https://kubernetes.github.io/ingress-nginx/), as installed by [enabling the Minikube ingress plugin](https://kubernetes.io/docs/tasks/access-application-cluster/ingress-minikube/) via the `minikube addons enable ingress` command. The ingress in this example provides ServicePulse at the root path, exposes the RavenDB error and audit instance consoles via the `/ravendb/error` and `/ravendb/audit` paths, as well as exposing the RabbitMQ management console via the `/rabbitmq` path. Of course these have different security concerns and a production ingress would look much different.

> [!WARNING]
> The ServiceControl RavenDB server and databases are used exclusively by ServiceControl and are not intended for external manipulation or modifications.