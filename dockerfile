FROM node:18-alpine

WORKDIR /usr/src/app


RUN apk add --no-cache curl

COPY package*.json ./

RUN npm install --production

COPY . .

ENV PORT=5000
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD curl -sSf http://localhost:${PORT}/ || exit 1

CMD ["node", "index.js"]

# check for the automatically trigger pipeline 
