# Running with Docker Compose

This [Docker Compose](https://docs.docker.com/compose/) file provides an example of spinning up [ServiceControl](https://docs.particular.net/servicecontrol/) and [ServicePulse](https://docs.particular.net/servicepulse/) in a local development environment, using a container-hosted [RabbitMQ](https://docs.particular.net/transports/rabbitmq/) broker as the message transport.

Running ServiceControl and ServicePulse locally in containers provides a way to use and test Service Platform features during local development on any platform, without needing to install Windows services.

## Usage

**Pull the latest images:** Before running the containers, ensure you're using the latest version of each image by executing the following command:

```pwsh
docker compose pull
```

**Start the containers:** After pulling the latest images, modify the [environment file](.env), if necessary, and then start up the containers using:

```pwsh
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

1. **SSL Certificate**: A PFX certificate file — see [Generating a certificate](#generating-a-certificate-local-testing-only) below
2. **CA Bundle**: A PEM file containing the CA that signed your certificate — see [Generating a CA bundle](#generating-a-ca-bundle-local-testing-only) below
3. **Microsoft Entra ID App Registration**: Configure an app registration for authentication

### Configuration

Update your `.env` file with the following values, replacing the `{placeholder}` values with your actual configuration:

```text
CERTIFICATE_PASSWORD="{password}"
CERTIFICATE_PATH="./certs/servicecontrol.pfx"
CA_BUNDLE_PATH="./certs/ca-bundle.crt"
IDP_AUTHORITY="https://login.microsoftonline.com/{tenant-id}"
SERVICECONTROL_AUDIENCE="api://{servicecontrol-client-id}"
SERVICEPULSE_CLIENTID="{servicepulse-client-id}"
SERVICEPULSE_APISCOPES=["api://{servicecontrol-client-id}/{scope-name}"]
```

| Variable                  | Description                                                                                                                              |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `CERTIFICATE_PASSWORD`    | Password for the PFX certificate                                                                                                         |
| `CERTIFICATE_PATH`        | Path to the PFX certificate file                                                                                                         |
| `CA_BUNDLE_PATH`          | Path to a PEM file containing the CA that signed the PFX. Containers use this to verify each other's certificates over HTTPS.            |
| `IDP_AUTHORITY`           | Microsoft Entra ID authority URL (e.g., `https://login.microsoftonline.com/{tenant-id}`)                                                 |
| `SERVICECONTROL_AUDIENCE` | Application ID URI from ServiceControl app registration (e.g., `api://{servicecontrol-client-id}`)                                       |
| `SERVICEPULSE_CLIENTID`   | Application (client) ID from ServicePulse app registration                                                                               |
| `SERVICEPULSE_APISCOPES`  | Array of API scopes ServicePulse should request when calling ServiceControl (e.g., `["api://{servicecontrol-client-id}/{scope-name}"]`)   |

#### Identity provider configuration examples

The `.env` values for `IDP_AUTHORITY`, `SERVICECONTROL_AUDIENCE`, `SERVICEPULSE_CLIENTID`, and `SERVICEPULSE_APISCOPES` depend on which identity provider you use.

<details>
<summary>Microsoft Entra ID</summary>

Register two app registrations in [Entra ID](https://entra.microsoft.com):

- **ServiceControl**: expose an API with an application ID URI and at least one scope
- **ServicePulse**: register as a single-page application; grant it permission to call the ServiceControl API

```text
IDP_AUTHORITY="https://login.microsoftonline.com/{tenant-id}"
SERVICECONTROL_AUDIENCE="api://{servicecontrol-client-id}"
SERVICEPULSE_CLIENTID="{servicepulse-client-id}"
SERVICEPULSE_APISCOPES=["api://{servicecontrol-client-id}/{scope-name}"]
```

</details>

<details>
<summary>Auth0</summary>

In your [Auth0 dashboard](https://manage.auth0.com):

- **API**: create an API whose *identifier* becomes `SERVICECONTROL_AUDIENCE`. Add a permission (scope) for ServicePulse to request.
- **Application**: create a Single Page Application for ServicePulse. Add `https://localhost:9090` to *Allowed Callback URLs*, *Allowed Logout URLs*, and *Allowed Web Origins*.

```text
IDP_AUTHORITY="https://{tenant}.auth0.com/"
SERVICECONTROL_AUDIENCE="{api-identifier}"
SERVICEPULSE_CLIENTID="{servicepulse-application-client-id}"
SERVICEPULSE_APISCOPES=["{api-identifier}/{permission-name}"]
```

> [!NOTE]
> The Auth0 authority URL requires a trailing slash.

</details>

<details>
<summary>Keycloak</summary>

In your Keycloak admin console:

- **ServiceControl client**: create a client with *Client authentication* enabled. Under *Client scopes*, add a dedicated scope (e.g., `servicecontrol:read`). Add an *Audience* mapper so the access token includes the ServiceControl client ID in the `aud` claim.
- **ServicePulse client**: create a public client with *Standard flow* and PKCE enabled. Add the ServiceControl scope as an optional or default scope.

```text
IDP_AUTHORITY="https://{keycloak-host}/realms/{realm}"
SERVICECONTROL_AUDIENCE="{servicecontrol-client-id}"
SERVICEPULSE_CLIENTID="{servicepulse-client-id}"
SERVICEPULSE_APISCOPES=["{servicecontrol-client-id}/{scope-name}"]
```

</details>

<details>
<summary>Duende IdentityServer</summary>

In your IdentityServer configuration:

- **ApiResource**: register a resource for ServiceControl with one or more scopes (e.g., `servicecontrol:read`).
- **Client**: register a client for ServicePulse using the `authorization_code` grant with PKCE. Grant it access to the ServiceControl scopes and set `RedirectUris` to `https://localhost:9090`.

```text
IDP_AUTHORITY="https://{your-identity-server}"
SERVICECONTROL_AUDIENCE="{api-resource-name}"
SERVICEPULSE_CLIENTID="{servicepulse-client-id}"
SERVICEPULSE_APISCOPES=["{api-resource-name}/{scope-name}"]
```

</details>

### Generating a certificate (local testing only)

> [!WARNING]
> The certificates generated below are for local testing only. Use a certificate from a trusted Certificate Authority for production deployments.

> [!IMPORTANT]
> The certificate must include every hostname used to access services over HTTPS. In a Docker Compose network, containers reach each other using their service names as hostnames (e.g., `https://servicecontrol:33333`). The TLS handshake checks that the server certificate contains a [Subject Alternative Name](https://en.wikipedia.org/wiki/Subject_Alternative_Name) (SAN) matching the hostname being connected to — if a name is missing, the connection is rejected.

#### Option 1: Using mkcert

Install [mkcert](https://github.com/FiloSottile/mkcert):

```pwsh
winget install FiloSottile.mkcert
```

Generate the certificate:

```pwsh
# One-time setup: add mkcert's root CA to your system trust store
mkcert -install

# Create the certs folder and generate a PFX covering all required hostnames
mkdir certs
mkcert -p12-file certs/servicecontrol.pfx -pkcs12 localhost 127.0.0.1 ::1 servicecontrol servicecontrol-audit servicecontrol-monitoring
```

> [!NOTE]
> mkcert sets the PKCS12 password to `changeit`. Set `CERTIFICATE_PASSWORD=changeit` in `.env`.

#### Option 2: Using PowerShell (no additional tools required)

Run the following from the `docker-compose` directory. Set `CERTIFICATE_PASSWORD=password` in `.env` (or change the password in the script and update `.env` to match).

```pwsh
# Create a local CA
$ca = New-SelfSignedCertificate `
    -Subject "CN=LocalDevCA" `
    -KeyUsageProperty Sign `
    -KeyUsage CertSign, CRLSign, DigitalSignature `
    -TextExtension @("2.5.29.19={critical}{text}ca=TRUE") `
    -KeyExportPolicy Exportable `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -NotAfter (Get-Date).AddYears(5)

# Create server cert signed by the CA, covering all required hostnames
$cert = New-SelfSignedCertificate `
    -Subject "CN=localhost" `
    -DnsName "localhost","servicecontrol","servicecontrol-audit","servicecontrol-monitoring" `
    -Signer $ca `
    -KeyExportPolicy Exportable `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -NotAfter (Get-Date).AddYears(2)

New-Item -ItemType Directory -Force certs | Out-Null

# Export the server cert as PFX
$password = ConvertTo-SecureString -String "password" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath "certs\servicecontrol.pfx" -Password $password

# Export the CA cert as PEM — this becomes the CA bundle
$caBytes = $ca.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
$caPem = "-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($caBytes, "InsertLineBreaks") + "`n-----END CERTIFICATE-----"
Set-Content -Path "certs\ca-bundle.crt" -Value $caPem -Encoding ASCII

# Remove temporary certs from the store
Remove-Item "Cert:\CurrentUser\My\$($ca.Thumbprint)" -Force
Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
```

#### Option 3: Using OpenSSL

> [!NOTE]
> On Windows, run these commands in Git Bash or WSL. OpenSSL 1.1.1 or later is required.

```bash
mkdir -p certs

# Generate a CA key and self-signed CA certificate
openssl genrsa -out certs/ca.key 4096
openssl req -x509 -new -nodes -key certs/ca.key -sha256 -days 1825 \
  -out certs/ca.crt -subj "/CN=LocalDevCA"

# Generate a server key and certificate signing request
openssl genrsa -out certs/servicecontrol.key 2048
openssl req -new -key certs/servicecontrol.key -out certs/servicecontrol.csr \
  -subj "/CN=localhost"

# Sign the server cert with the CA, including all required SANs
openssl x509 -req -in certs/servicecontrol.csr \
  -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
  -out certs/servicecontrol.crt -days 730 -sha256 \
  -addext "subjectAltName=DNS:localhost,DNS:servicecontrol,DNS:servicecontrol-audit,DNS:servicecontrol-monitoring,IP:127.0.0.1,IP:::1"

# Bundle into a PFX (password: "password")
openssl pkcs12 -export -out certs/servicecontrol.pfx \
  -inkey certs/servicecontrol.key -in certs/servicecontrol.crt \
  -certfile certs/ca.crt -passout pass:password

# Use the CA cert as the CA bundle
cp certs/ca.crt certs/ca-bundle.crt

# Remove intermediate files
rm certs/ca.key certs/servicecontrol.key certs/servicecontrol.csr certs/ca.srl
```

Set `CERTIFICATE_PASSWORD=password` in `.env`. The CA bundle is generated by this script — no additional step needed.

### Generating a CA bundle (local testing only)

> [!WARNING]
> The CA bundle generated below is for local testing only. Use certificates from a trusted Certificate Authority for production deployments.

Docker containers don't share the host's certificate trust store. The CA bundle provides containers with the CA certificates they need to verify HTTPS connections to other services — including the internal healthcheck that determines whether a container is ready. Without it, containers will reject HTTPS connections and fail their healthchecks.

#### Using mkcert

If you used mkcert to generate the certificate, copy its root CA as the bundle:

```pwsh
copy "$(mkcert -CAROOT)\rootCA.pem" certs\ca-bundle.crt
```

#### Using PowerShell

The PowerShell script above already writes `certs\ca-bundle.crt` as part of cert generation. No additional step is needed.

#### Using OpenSSL

The OpenSSL script above already writes `certs/ca-bundle.crt` as part of cert generation. No additional step is needed.

### Pull the latest images

Before running the containers, ensure you're using the latest version of each image:

```pwsh
docker compose -f compose-secure.yml pull
```

### Start the containers

```pwsh
docker compose -f compose-secure.yml up -d
```

Once running, [ServicePulse](https://docs.particular.net/servicepulse/) can be accessed at https://localhost:9090.

### Troubleshooting

#### Container is unhealthy but logs show no errors

Docker's healthcheck output is separate from container logs. To see the actual failure reason:

```pwsh
docker inspect --format='{{json .State.Health}}' service-platform-servicecontrol-1
```

Common causes and fixes:

| Error | Cause | Fix |
|---|---|---|
| `UntrustedRoot` | CA bundle is empty or doesn't contain the CA that signed the PFX | Verify `certs\ca-bundle.crt` is non-empty and was generated from the same CA used to sign the PFX |
| `The SSL connection could not be established` | Certificate is missing a required SAN (e.g., `localhost`) or the PFX file is invalid | Regenerate the certificate ensuring all hostnames are included |
| File not found / empty cert | `CERTIFICATE_PATH` in `.env` points to a file that doesn't exist | Check the path is correct and the file exists on the host before starting containers |
| `AuthenticationException` | `CERTIFICATE_PASSWORD` in `.env` doesn't match the password used to generate the PFX | Update `CERTIFICATE_PASSWORD` to match (mkcert uses `changeit` by default) |
