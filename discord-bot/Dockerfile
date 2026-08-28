FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
# Panel/ticket state lives here; mount it or the bot re-posts panels after a rebuild.
VOLUME ["/app/data"]
CMD ["node", "src/index.js"]
