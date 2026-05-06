# syntax=docker/dockerfile:1

FROM python:3.12.8-slim-bookworm AS builder
WORKDIR /app

COPY requirements.txt .
RUN python -m venv /opt/venv \
    && . /opt/venv/bin/activate \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

FROM python:3.12.8-slim-bookworm AS final
WORKDIR /app

RUN useradd --create-home --shell /bin/bash --uid 1000 appuser

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder --chown=appuser:appuser /app /app

ENV PATH="/opt/venv/bin:${PATH}"

USER appuser

EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8001/health')" || exit 1

ENTRYPOINT ["uvicorn"]
CMD ["app.main:app", "--host", "0.0.0.0", "--port", "8001"]
