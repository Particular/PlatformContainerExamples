# particular-platform

Helm chart to install the Particular Platform components; a set of components that allows customer to monitor and manage errors on NServiceBus and MassTransit endpoints.

**Homepage:** <https://particular.net/>

## Before installing the chart

In order to use the particular-platform chart, you need the following infrastructure.

1. A RavenDB server (see below for instructions)
2. A broker connection string

We recommend install raven using our container [`particular/servicecontrol-ravendb`](https://hub.docker.com/r/particular/servicecontrol-ravendb).

## Installing the Chart

To install the chart just to have a look.
This setup creates a `test-particular-platform` namespace.

```shell
helm install --generate-name --create-namespace --namespace test-particular-platform .
```

To install the chart on a production environment.
This setup creates a `particular-platform` namespace and adds the license to the chart and also references an extra values override file for extra customization.

```shell
helm install --generate-name --create-namespace --namespace particular-platform -f <path to values overrides yaml file> --set-file licenseData=<path to license file>/license.xml .
```

Example of a values_override.yaml file. For more options see [values.yaml](./values.yaml)

```yaml
transport:
  # the connection string to connect to the broker, see https://docs.particular.net/servicecontrol/transports
  connectionString: "host=my-rabbit;virtualhost=k8s;"
  # the broker type, see https://docs.particular.net/servicecontrol/transports
  type: "RabbitMQ.QuorumConventionalRouting"

ravenDBUrl: "http://my-ravendb:8080"

audit:
  # Suffixed instances with dedicated queues:
  instances:
    - suffix: "sales"
      queue: "sales.audit"
    - suffix: "marketing"
      queue: "marketing.audit"

  # or a combination of default queue names and a custom one
  instances:
    - suffix: "1"
    - suffix: "2"
    - suffix: "3"
      queue: "my_custom_queuename"

  # it is also possible to override the ravenDBUrl
    instances:
    - suffix: "sales"
      queue: "sales.audit"
      ravenDBUrl: "http://ravendb-custom:8081"
    - suffix: "marketing"
      queue: "marketing.audit"
      ravenDBUrl: "http://ravendb-custom:8082"


pulse:
  service:
    # The type of service to create
    type: "LoadBalancer"
```

## RavenDB deployment

If the [storage requirements for the RavenDB container](https://docs.particular.net/servicecontrol/ravendb/containers#required-settings) cannot be met by the container hosting infrastructure, especially in cloud-hosted environments, an externally-hosted and separately-licensed RavenDB instance can also be used.

### Deploying RavenDB on an AKS cluster

The first thing we need to do is [enable CSI storage drivers](https://learn.microsoft.com/en-us/azure/aks/csi-storage-drivers#enable-csi-storage-drivers-on-an-existing-cluster) on your cluster.
In this example we are enabling [Azure Disks CSI driver](https://learn.microsoft.com/en-us/azure/aks/azure-disk-csi).

```shell
az aks update --name <cluster name> --resource-group <rg name> --enable-disk-driver
```

Once that is completed, you can run apply the following manifest:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: particular-ravendb
  labels:
    app.kubernetes.io/name: particular-ravendb
spec:
  serviceName: particular-ravendb
  selector:
    matchLabels:
      app.kubernetes.io/name: particular-ravendb
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain
  volumeClaimTemplates:
    - metadata:
        name: raven-data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: managed-csi
        resources:
          requests:
            storage: 25Gi
  template:
    metadata:
      labels:
        app.kubernetes.io/name: particular-ravendb
    spec:
      securityContext:
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      containers:
        - name: servicecontrol-ravendb
          image: particular/servicecontrol-ravendb:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
              name: http-api
              protocol: TCP
            - containerPort: 161
              name: snmp
              protocol: TCP
          volumeMounts:
            - name: raven-data
              mountPath: /var/lib/ravendb/data
---
apiVersion: v1
kind: Service
metadata:
  name: particular-ravendb
  labels:
    app.kubernetes.io/name: particular-ravendb
spec:
  ports:
    - name: http-api
      port: 8080
      protocol: TCP
      targetPort: 8080
    - name: snmp
      port: 161
      protocol: TCP
      targetPort: 161
  selector:
    app.kubernetes.io/name: particular-ravendb
  type: ClusterIP
```

### Deploying RavenDB on an EKS cluster

You can run apply the following manifest.
This manifest assumes that the cluster was created using the new EKD Auto Mode.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.eks.amazonaws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: particular-ravendb
  labels:
    app.kubernetes.io/name: particular-ravendb
spec:
  serviceName: particular-ravendb
  selector:
    matchLabels:
      app.kubernetes.io/name: particular-ravendb
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain
  volumeClaimTemplates:
    - metadata:
        name: raven-data
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: ebs-sc
        resources:
          requests:
            storage: 25Gi
  template:
    metadata:
      labels:
        app.kubernetes.io/name: particular-ravendb
    spec:
      securityContext:
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      nodeSelector:
        eks.amazonaws.com/compute-type: auto
      containers:
        - name: servicecontrol-ravendb
          image: particular/servicecontrol-ravendb:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
              name: http-api
              protocol: TCP
            - containerPort: 161
              name: snmp
              protocol: TCP
          volumeMounts:
            - name: raven-data
              mountPath: /var/lib/ravendb/data
---
apiVersion: v1
kind: Service
metadata:
  name: particular-ravendb
  labels:
    app.kubernetes.io/name: particular-ravendb
spec:
  ports:
    - name: http-api
      port: 8080
      protocol: TCP
      targetPort: 8080
    - name: snmp
      port: 161
      protocol: TCP
      targetPort: 161
  selector:
    app.kubernetes.io/name: particular-ravendb
  type: ClusterIP
```
