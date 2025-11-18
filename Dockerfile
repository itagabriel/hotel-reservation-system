FROM python:3.11.3-alpine3.18
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN apk add --no-cache build-base postgresql-dev libffi-dev musl-dev openssl-dev \
 && python -m venv /venv \
 && /venv/bin/pip install --upgrade pip \
 && /venv/bin/pip install -r /app/requirements.txt

COPY . /app

# normalize windows EOL if present and make entrypoint executable
RUN sed -i 's/\r$//' /app/docker-entrypoint/entrypoint.sh || true \
 && chmod +x /app/docker-entrypoint/entrypoint.sh

ENV PATH="/venv/bin:$PATH"

USER root
EXPOSE 8000

ENTRYPOINT ["/app/docker-entrypoint/entrypoint.sh"]
