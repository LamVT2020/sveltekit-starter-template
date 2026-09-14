# ==============================================================================
# 🚀 SvelteKit Starter Template - Multi-stage Production Dockerfile (Port 3005)
# ==============================================================================

# Stage 1: Build application
FROM node:22-bookworm-slim AS builder

WORKDIR /app

# Install native dependencies and OpenSSL for Prisma
RUN apt-get update && apt-get install -y openssl python3 make g++ && rm -rf /var/lib/apt/lists/*

# Copy dependency manifests & Prisma schema
COPY package.json package-lock.json* ./
COPY prisma ./prisma/

# Install dependencies and generate Prisma Client
RUN npm install --no-audit --no-fund
RUN npx prisma generate

# Copy source code and build
COPY . .
RUN npm run build

# Stage 2: Production runner
FROM node:22-bookworm-slim AS runner

WORKDIR /app

# Install runtime dependencies: OpenSSL (Prisma requirement), curl (healthcheck), dumb-init, gosu
RUN apt-get update && apt-get install -y openssl curl dumb-init gosu && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production \
    PORT=3005 \
    HOST=0.0.0.0 \
    DATABASE_URL="file:/app/data/starter.db"

# Copy built artifacts and dependencies with node ownership
COPY --chown=node:node --from=builder /app/package.json ./
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/build ./build
COPY --chown=node:node --from=builder /app/prisma ./prisma
COPY --chown=node:node --from=builder /app/scripts ./scripts

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create persistent storage directories and assign permissions
RUN mkdir -p /app/data /app/logs && chown -R node:node /app/data /app/logs

USER node

EXPOSE 3005

VOLUME ["/app/data"]

ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/docker-entrypoint.sh"]

CMD ["node", "build/index.js"]
