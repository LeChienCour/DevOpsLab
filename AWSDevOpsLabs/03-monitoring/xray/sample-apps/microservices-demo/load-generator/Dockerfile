FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV USER_SERVICE_URL=http://user-service:5000
ENV ORDER_SERVICE_URL=http://order-service:5001

CMD ["python", "app.py"]