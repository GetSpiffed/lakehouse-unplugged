FROM python:3.11-slim

RUN pip install requests

WORKDIR /app
COPY bootstrap.py /app/bootstrap.py

CMD ["python", "/app/bootstrap.py"]
