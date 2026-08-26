# Container image for Particular/ServiceControl.SmokeTest
# Installs the published dotnet tool from feedz.io (no source clone required,
# no image published to a registry - built locally by docker compose).

FROM mcr.microsoft.com/dotnet/sdk:10.0

ENV DOTNET_TOOLS_PATH=/root/.dotnet/tools
ENV PATH=$PATH:$DOTNET_TOOLS_PATH

RUN dotnet tool install -g ServiceControl.SmokeTest \
    --add-source https://f.feedz.io/particular-software/packages/nuget/index.json

WORKDIR /learningtransport

# Keep the container running so a user can `docker exec -it` into it
# and drive the interactive tool manually against the shared Learning
# Transport volume.
CMD ["tail", "-f", "/dev/null"]
