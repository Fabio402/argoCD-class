# Stage 1: build
FROM node:22-alpine AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: runtime
FROM node:22-alpine
WORKDIR /usr/src/app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force
COPY --from=builder /usr/src/app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/main"]
