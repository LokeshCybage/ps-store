# syntax=docker/dockerfile:1

FROM node:20.18.1-bookworm-slim AS builder
WORKDIR /build

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

COPY index.html vite.config.js ./
COPY src ./src

ARG VITE_CATALOG_API=http://localhost:8001
ARG VITE_USER_API=http://localhost:8002
ARG VITE_ORDER_API=http://localhost:8003

ENV VITE_CATALOG_API=${VITE_CATALOG_API}
ENV VITE_USER_API=${VITE_USER_API}
ENV VITE_ORDER_API=${VITE_ORDER_API}

RUN npm run build

FROM nginx:1.27.4-alpine AS final

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /build/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget -q -O- http://127.0.0.1/ >/dev/null || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
