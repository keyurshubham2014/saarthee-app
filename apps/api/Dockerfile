# Saarthee API production image (V2 TASK-13 step 5).
# Build:  docker build -t saarthee-api:<sha> apps/api
# Run:    see infra/deploy/compose.yml (the API port is never published; Caddy fronts it).
# Migrate (one-off): docker run --rm --env-file api.env saarthee-api:<sha> npx prisma migrate deploy

# ---- build: full dependencies, Prisma client, TypeScript → dist/ ----
FROM node:20.19-bookworm-slim AS build
# python3/make/g++: native modules (argon2) compile from source when no prebuild matches the platform.
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates python3 make g++ \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json ./
COPY prisma ./prisma
COPY src ./src
COPY scripts ./scripts
RUN npm run build \
  && mkdir -p dist/scripts/data && cp scripts/data/*.txt dist/scripts/data/

# ---- deps: production node_modules (native modules built here, with the toolchain) ----
FROM build AS deps
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma

# ---- runtime: production dependencies only (Prisma CLI is a dependency for migrate deploy) ----
FROM node:20.19-bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates tini \
  && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production \
    APP_ENV=production \
    API_HOST=0.0.0.0 \
    API_PORT=3000 \
    NPM_CONFIG_UPDATE_NOTIFIER=false
WORKDIR /app
COPY package.json package-lock.json ./
# Production dependencies + generated Prisma client (engines included); no toolchain in this stage.
COPY --from=deps /app/node_modules ./node_modules
COPY prisma ./prisma
COPY --from=build /app/dist ./dist
# Non-root user; /data holds local photos/logs only when STORAGE_DRIVER=local (volume).
RUN groupadd --system --gid 10001 saarthee \
  && useradd --system --uid 10001 --gid saarthee --home /app --shell /usr/sbin/nologin saarthee \
  && mkdir -p /data/photos /data/logs && chown -R saarthee:saarthee /data
USER saarthee
ARG APP_RELEASE=dev
ENV APP_RELEASE=${APP_RELEASE}
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.API_PORT||3000)+'/api/v1/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "dist/src/server.js"]
