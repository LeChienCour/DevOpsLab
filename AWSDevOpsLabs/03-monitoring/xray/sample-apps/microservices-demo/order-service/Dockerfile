FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Install X-Ray daemon
RUN apt-get update && \
    apt-get install -y wget unzip && \
    wget https://s3.us-east-2.amazonaws.com/aws-xray-assets.us-east-2/xray-daemon/aws-xray-daemon-linux-3.x.zip && \
    unzip aws-xray-daemon-linux-3.x.zip && \
    cp xray /usr/local/bin/ && \
    rm -rf aws-xray-daemon-linux-3.x.zip && \
    apt-get purge -y --auto-remove wget unzip && \
    rm -rf /var/lib/apt/lists/*

# Create startup script
RUN echo '#!/bin/bash\n\
/usr/local/bin/xray -o -n $AWS_REGION &\n\
python app.py\n' > /app/start.sh && \
    chmod +x /app/start.sh

ENV PORT=5001
ENV AWS_REGION=us-east-1
ENV ORDERS_TABLE_NAME=Orders
ENV USER_SERVICE_URL=http://user-service:5000

EXPOSE 5001

CMD ["/app/start.sh"]