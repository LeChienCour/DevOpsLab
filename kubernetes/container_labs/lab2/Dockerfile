#STAGE 1
FROM node:18-alpine as builder

WORKDIR /app

RUN apk update && apk upgrade

COPY . ./

RUN npm install

RUN npm run build

RUN npm run clean


#Stage 2
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]