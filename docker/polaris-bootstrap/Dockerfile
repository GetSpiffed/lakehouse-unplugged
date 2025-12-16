FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir requests==2.32.3

WORKDIR /app
COPY bootstrap.py /app/bootstrap.py

CMD ["python", "/app/bootstrap.py"]
