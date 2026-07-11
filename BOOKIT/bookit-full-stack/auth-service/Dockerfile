# ---- Build stage ----
# Includes devDependencies (typescript, ts types) needed only to compile.
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ---- Production stage ----
# Fresh, minimal image: only production deps + compiled JS, nothing else.
FROM node:20-alpine AS production

# Run as a non-root user - if the process is ever compromised, it doesn't
# have root inside the container. node:20-alpine already ships a "node"
# user/group for exactly this purpose.
RUN apk add --no-cache wget

WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=build /app/dist ./dist

USER node

EXPOSE 3001

# Kubernetes/Docker use this to know when the container can actually serve
# traffic - matches the /health/live endpoint every service exposes.
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --spider -q http://localhost:3001/health/live || exit 1

CMD ["node", "dist/index.js"]
