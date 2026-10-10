---
name: agent-ship
description: Prepares a multi-agent application for production deployment — generates Docker containerization with non-root security, externalized environment configuration, database migration checks for Postgres checkpointer, and health check endpoints.
---

# agent-ship

**Verb: ship-agent.**

## 1. Production Deployment Invariants

1. **Non-Root Execution**: Container runs under an unprivileged `appuser`.
2. **Secrets via Environment Variables**: Model API keys (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc.) and database connection strings are injected via runtime environment variables or Docker secrets.
3. **Health Check Endpoint**: The agent exposes `/healthz` returning 200 OK only when the checkpointer database connection is active.
4. **Log Sanitization**: Enforces strict logging policies — prompts and model completions with user PII are never dumped to stdout.

## 2. Dockerfile Template

```dockerfile
FROM python:3.12-slim-bookworm

WORKDIR /app

RUN useradd -m -u 1000 appuser && \
    apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

USER appuser

EXPOSE 8000
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```
