# syntax=docker/dockerfile:1

FROM node:20.18.1-bookworm-slim AS builder
WORKDIR /build

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

COPY src ./src

FROM node:20.18.1-bookworm-slim AS final
WORKDIR /app

COPY package.json package-lock.json ./
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/src ./src

ENV NODE_ENV=production

USER node

EXPOSE 8003

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8003/health',(r)=>{let e=r.statusCode===200?0:1;r.resume();process.exit(e);}).on('error',()=>process.exit(1))"

ENTRYPOINT ["node"]
CMD ["src/index.js"]
