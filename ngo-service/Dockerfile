FROM python:3.11-slim AS builder

WORKDIR /app
COPY requirements.lock .
RUN pip install --no-cache-dir --no-deps --prefix=/install -r requirements.lock

FROM python:3.11-slim

RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid 1000 --create-home appuser

WORKDIR /app
COPY --from=builder /install /usr/local
COPY --chown=1000:1000 app.py .

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8081

USER 1000:1000
EXPOSE 8081

CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} --graceful-timeout 30 --timeout 30 --error-logfile - app:app"]
