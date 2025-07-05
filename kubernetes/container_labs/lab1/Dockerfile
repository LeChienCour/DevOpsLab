FROM alpine:latest

RUN apk update && apk upgrade

WORKDIR /app

COPY . ./

RUN chmod +x ./app

ENTRYPOINT ["./app", "echo", "Hello, World!"]