# ========== Stage 1: Build Admin ==========
FROM node:20-alpine AS admin-builder
WORKDIR /admin
COPY admin/package*.json ./
RUN npm ci
COPY admin/ ./
RUN npm run build

# ========== Stage 2: Build Server ==========
FROM node:20-alpine AS server-builder
WORKDIR /app
COPY server/package*.json ./
RUN npm ci
COPY server/ ./
RUN npm run build

# ========== Stage 3: Production ==========
FROM node:20-alpine
WORKDIR /app
COPY server/package*.json ./
RUN npm ci --only=production
COPY --from=server-builder /app/dist ./dist

# Admin static files (baked into image)
COPY --from=admin-builder /admin/dist ./public/admin

# Copy dist download page
COPY server/public/dist ./public/dist

# Data directory for SQLite DB and local uploads (when using local storage)
RUN mkdir -p /app/data/uploads /app/public/app
VOLUME ["/app/data"]

EXPOSE 3000
CMD ["node", "dist/main.js"]
