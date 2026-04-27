FROM mcr.microsoft.com/dotnet/sdk:8.0.404-bookworm-slim AS builder
WORKDIR /src

COPY user-service.csproj .
RUN --mount=type=cache,target=/root/.nuget \
    dotnet restore user-service.csproj

COPY . .
RUN dotnet publish user-service.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0.11-bookworm-slim AS final
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1000 app \
    && useradd --system --uid 1000 --gid app --shell /bin/false --no-create-home app

COPY --from=builder /app/publish .

USER app

EXPOSE 8002

ENV ASPNETCORE_URLS=http://0.0.0.0:8002

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://127.0.0.1:8002/health || exit 1

ENTRYPOINT ["dotnet"]
CMD ["UserService.dll"]