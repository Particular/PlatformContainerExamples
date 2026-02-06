# Running with Docker Compose

This [Docker Compose](https://docs.docker.com/compose/) file provides an example of spinning up [ServiceControl](https://docs.particular.net/servicecontrol/) and [ServicePulse](https://docs.particular.net/servicepulse/) in a local development environment, using a container-hosted [RabbitMQ](https://docs.particular.net/transports/rabbitmq/) broker as the message transport.

Running ServiceControl and ServicePulse locally in containers provides a way to use and test Service Platform features during local development on any platform, without needing to install Windows services.

## Usage

 **Pull the latest images:** Before running the containers, ensure you're using the latest version of each image by executing the following command:

 ```shell
 docker compose pull
 ```

This command checks for any updates to the images specified in the docker-compose.yml file and pulls them if available.

**Start the containers:** After pulling the latest images, modify the [environment file](.env), if necessary, and then start up the containers using:

```shell
docker compose up -d
```

Once composed:

- [ServicePulse](https://docs.particular.net/servicepulse/) can be accessed at http://localhost:9090
- [ServiceInsight](https://docs.particular.net/serviceinsight/) can be used with a connection URL of http://localhost:33333/api

## Implementation details

- The ports for all services are exposed to localhost:
  - `33333`: ServiceControl API
  - `44444`: Audit API
  - `33633`: Monitoring API
  - `8080`: Database backend
  - `9090` ServicePulse UI
- One instance of the [`servicecontrol-ravendb` container](https://docs.particular.net/servicecontrol/ravendb/containers) is used for both the [`servicecontrol`](https://docs.particular.net/servicecontrol/servicecontrol-instances/deployment/containers) and [`servicecontrol-audit`](https://docs.particular.net/servicecontrol/audit-instances/deployment/containers) containers.
  - _A single database container should not be shared between multiple ServiceControl instances in production scenarios._

## Running with HTTPS and authentication

The `compose-secure.yml` file provides a configuration with HTTPS enabled and OAuth2/OIDC authentication using Microsoft Entra ID (Azure AD).

### Prerequisites

1. **SSL Certificate**: A PFX certificate file for HTTPS
2. **CA Bundle**: A CA certificate bundle for validating the identity provider's certificates
3. **Microsoft Entra ID App Registration**: Configure an app registration for authentication

> [!NOTE]
> The PFX file contains the private key and certificate for the service to **serve** HTTPS. The CA bundle contains only public CA certificates for the service to **verify** other services' certificates. Both are required when containers communicate over HTTPS.

### Configuration

Update as needed, and copy the following variables into the `.env` file.

```text
CERTIFICATE_PASSWORD=""
CERTIFICATE_PATH=""
CA_BUNDLE_PATH=""
IDP_AUTHORITY=""
SERVICECONTROL_AUDIENCE=""
SERVICEPULSE_CLIENTID=""
SERVICEPULSE_APISCOPES=''
```

| Variable                  | Description                                                                              |
|---------------------------|------------------------------------------------------------------------------------------|
| `CERTIFICATE_PASSWORD`    | Password for the PFX certificate                                                         |
| `CERTIFICATE_PATH`        | Path to the PFX certificate file (e.g.: `./certs/certificate.pfx`)                       |
| `CA_BUNDLE_PATH`          | Path to the CA bundle file (default: `./certs/ca-bundle.crt`)                            |
| `IDP_AUTHORITY`           | Microsoft Entra ID authority URL (e.g., `https://login.microsoftonline.com/{tenant-id}`) |
| `SERVICECONTROL_AUDIENCE` | API audience URI (e.g., `api://{client-id}`)                                             |
| `SERVICEPULSE_CLIENTID`   | ServicePulse app registration client ID                                                  |
| `SERVICEPULSE_APISCOPES`  | Array of API scopes. e.g. `["api://{client-id}"]`                                        |

#### Generate a PFX Certificate for Local Testing Only

> [!WARNING]
> The certificate generated below is for local testing only. Use a certificate from a trusted Certificate Authority for production deployments.

The below assume the `mkcert` tool has been installed.

```cmd
# Install mkcert's root CA (one-time setup)
mkcert -install

# Navigate to a certs folder. e.g.
cd certs

# Generate PFX certificate for localhost
mkcert -p12-file localhost.pfx -pkcs12 localhost 127.0.0.1 ::1 servicecontrol servicecontrol-audit servicecontrol-monitor
```

#### Generate a CA Bundle for Local Testing Only

> [!WARNING]
> The CA bundle generated below is for local testing only. Use certificates from a trusted Certificate Authority for production deployments.

When running ServiceControl in Docker containers, each container needs a CA bundle file to trust certificates presented by other services. The `SSL_CERT_FILE` environment variable tells .NET where to find this bundle.

#### What is a CA Bundle?

A CA bundle is a file containing one or more Certificate Authority (CA) certificates. When a container makes an HTTPS request to another service, it uses this bundle to verify the server's certificate chain. Without it, containers would reject connections to services using your mkcert certificates.

#### Why is it needed?

Unlike your host machine (where `mkcert -install` adds the CA to the system trust store), Docker containers don't share the host's trust store. You must explicitly provide the CA certificates that containers should trust.

#### Generate the CA bundle

```cmd
REM Get the mkcert CA root location
for /f "delims=" %i in ('mkcert -CAROOT') do set CA_ROOT=%i

REM For local development only (just mkcert CA)
copy "%CA_ROOT%\rootCA.pem" certs\ca-bundle.crt

REM For local development with external HTTPS calls (e.g., Azure AD authentication)
REM Download Mozilla's public CA bundle and combine with mkcert CA
copy "%CA_ROOT%\rootCA.pem" certs\ca-bundle.crt
curl -s https://curl.se/ca/cacert.pem >> certs\ca-bundle.crt
```

### Starting the secure containers

```shell
docker compose -f compose-secure.yml up -d
```

Once composed:

- [ServicePulse](https://docs.particular.net/servicepulse/) can be accessed at `https://localhost:9090`
