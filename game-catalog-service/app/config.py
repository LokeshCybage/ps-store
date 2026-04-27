import os

from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/catalog_db")
PORT = int(os.getenv("PORT", "8001"))
JWT_SECRET = os.getenv("JWT_SECRET", "ps-store-jwt-secret-key-change-in-production")
ORDER_SERVICE_URL = os.getenv("ORDER_SERVICE_URL", "http://localhost:8003")
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://localhost:8002")

OTEL_EXPORTER_ZIPKIN_ENDPOINT = os.getenv(
    "OTEL_EXPORTER_ZIPKIN_ENDPOINT",
    "http://localhost:9411/api/v2/spans",
)
OTEL_SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "game-catalog-service")
