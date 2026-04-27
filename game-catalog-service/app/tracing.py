"""OpenTelemetry setup and Zipkin export for the catalog service."""

from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.exporter.zipkin.json import ZipkinExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from app.config import OTEL_EXPORTER_ZIPKIN_ENDPOINT, OTEL_SERVICE_NAME


def configure_tracing() -> None:
    """Configures the tracer provider, Zipkin export, and HTTPX propagation."""
    resource = Resource.create(
        {
            "service.name": OTEL_SERVICE_NAME,
        }
    )
    provider = TracerProvider(resource=resource)
    exporter = ZipkinExporter(endpoint=OTEL_EXPORTER_ZIPKIN_ENDPOINT)
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)
    HTTPXClientInstrumentor().instrument()


def instrument_fastapi(app: FastAPI) -> None:
    """Attaches OpenTelemetry to the FastAPI application.

    Args:
        app: The FastAPI application instance.
    """
    FastAPIInstrumentor.instrument_app(app)
