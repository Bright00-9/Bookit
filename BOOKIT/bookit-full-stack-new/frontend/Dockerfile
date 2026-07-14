# ---- Build stage ----
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Vite env vars are baked into the JS bundle at BUILD time, not read at
# container startup - there's no "process.env" in a static SPA once it's
# in the browser. So the API base URL has to be supplied as a build arg,
# meaning you need a separate image build per environment (dev/staging/
# prod) if the gateway URL differs between them - a real tradeoff of
# static SPAs vs server-rendered apps.
ARG VITE_API_BASE_URL=http://localhost:8080
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

RUN npm run build

# ---- Production stage ----
# nginx:alpine is ~40MB total - far smaller than shipping node_modules
# and a Node runtime just to serve static files.
FROM nginx:alpine AS production

RUN apk add --no-cache wget

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --spider -q http://localhost:80/health/live || exit 1

CMD ["nginx", "-g", "daemon off;"]
