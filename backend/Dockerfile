FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt ./

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/
COPY migrations/ ./migrations/
COPY alembic.ini ./
COPY entrypoint.sh ./

RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

CMD ["/bin/sh", "/app/entrypoint.sh"]
