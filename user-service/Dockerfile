FROM mcr.microsoft.com/dotnet/sdk:8.0.404-bookworm-slim AS builder
WORKDIR /src

COPY user-service.csproj .
RUN dotnet restore user-service.csproj

COPY . .
RUN dotnet publish user-service.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0.11-bookworm-slim AS final
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/publish .

USER 1000:1000

EXPOSE 8002

ENV ASPNETCORE_URLS=http://0.0.0.0:8002

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://127.0.0.1:8002/health || exit 1

ENTRYPOINT ["dotnet"]
CMD ["user-service.dll"]