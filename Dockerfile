FROM python:3.8.10-slim-buster

WORKDIR /app

COPY ./app /app/

RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    libjpeg-dev \
    zlib1g-dev \
    build-essential \
    libffi-dev \
    netcat \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    chmod +x entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]

