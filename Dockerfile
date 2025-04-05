ARG PYTHON_VERSION=3.10

# Builder
FROM python:${PYTHON_VERSION}-slim AS builder

ENV UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=0

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# RUN apk add --update git build-base libffi-dev curl-dev

WORKDIR /app

# Install requirements
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev

# Runtime
FROM python:${PYTHON_VERSION}-slim

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE=1

# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED=1

# RUN apk add --no-cache curl

# cURL Impersonate libraries
COPY --from=builder /usr/local/bin/curl_* /usr/local/bin/
COPY --from=builder /usr/local/lib/libcurl-* /usr/local/lib/

# Copy pip requirements
COPY --from=builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

WORKDIR /cron

RUN set -x \
    && apt-get update \
    && apt-get install -y cron \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && chmod gu+rw /var/run \
    && chmod gu+s /usr/sbin/cron

WORKDIR /mount
ENV PYTHONPATH="/mount"

# Creates a non-root user with an explicit UID and adds permission to access the /app folder
RUN adduser --uid 1000 --gid 100 --disabled-password --gecos "" appuser \
    && touch /var/log/cron.log \
    && chown -R appuser:users /var/log/cron.log
USER appuser
