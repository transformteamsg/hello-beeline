# Multi-stage build mirroring the Beeline platform Dockerfile (minus Prisma).
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:24-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:24-alpine AS runner
WORKDIR /app
RUN addgroup -S nodejs && adduser -S nodejs -G nodejs
ENV NODE_ENV=production

COPY --from=builder /app/next.config.ts ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

USER nodejs

EXPOSE 3000

# Use the bundled node runtime for the probe (no curl/wget dependency).
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["node", "-e", "require('http').get('http://localhost:3000/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"]

CMD ["npm", "start"]
