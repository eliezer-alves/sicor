FROM python:3.10-slim

RUN apt-get update && apt-get install -y gcc libpq-dev

WORKDIR /app

COPY . .

RUN pip install pandas psycopg2-binary shapely

