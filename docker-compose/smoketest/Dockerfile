# Container image for Particular/ServiceControl.SmokeTest
# Builds the dotnet tool from source (no image is published to a registry)
# and installs it as a global dotnet tool so it's available on PATH.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

ARG SMOKETEST_REPO=https://github.com/Particular/ServiceControl.SmokeTest.git
ARG SMOKETEST_REF=main

WORKDIR /src

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${SMOKETEST_REF} ${SMOKETEST_REPO} .

RUN dotnet pack src/ServiceControl.SmokeTest/ServiceControl.SmokeTest.csproj \
    -c Release \
    -o /out

FROM mcr.microsoft.com/dotnet/sdk:10.0

ENV DOTNET_TOOLS_PATH=/root/.dotnet/tools
ENV PATH=$PATH:$DOTNET_TOOLS_PATH

COPY --from=build /out /nugets

RUN dotnet tool install --global ServiceControl.SmokeTest \
    --add-source /nugets \
    --version $(ls /nugets/*.nupkg | sed -E 's/.*ServiceControl\.SmokeTest\.([0-9][^ ]*)\.nupkg/\1/')

WORKDIR /learningtransport

# Keep the container running so a user can `docker exec -it` into it
# and drive the interactive tool manually against the shared Learning
# Transport volume.
CMD ["tail", "-f", "/dev/null"]
