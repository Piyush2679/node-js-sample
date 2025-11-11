FROM node:18-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

ENV PORT=5000
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -q -O- http://localhost:${PORT}/ || exit 1

CMD ["node", "index.js"]
