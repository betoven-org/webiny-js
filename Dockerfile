# syntax=docker/dockerfile:1
#
# Multi-stage build for the Webiny monorepo in standalone (self-hosted) mode.
# Targets: api (Node.js) and admin (Nginx SPA).

# --- builder: build monorepo packages then produce the self-contained app artifacts ---------------
FROM node:24-bookworm AS builder
WORKDIR /project

# Do NOT set NODE_ENV=production here — devDependencies (tsx, typescript, build-tools) are needed
# for the monorepo build step.
COPY . .
RUN corepack enable && yarn install --immutable

# Build all monorepo packages (compiles TS to dist/ for every @webiny/* package).
RUN yarn build

# Now set standalone env and build the apps.
ENV WEBINY_HOSTING_TYPE=standalone
ENV WEBINY_DB=postgres

ARG WEBINY_API_URL=http://localhost:3002
ENV WEBINY_API_URL=$WEBINY_API_URL

# Use the standalone CLI (via tsx since it's TypeScript source in the monorepo).
RUN npx tsx packages/cli-standalone/src/bin.ts build api
RUN npx tsx packages/cli-standalone/src/bin.ts build admin

# --- api: run the self-contained handler (node start.mjs) ---------------------------------------
FROM node:24-bookworm-slim AS api
WORKDIR /app
COPY --from=builder /project/.webiny/workspace/apps/api/graphql/build ./
ENV PORT=3002
EXPOSE 3002
CMD ["node", "start.mjs"]

# --- admin: static bundle served by nginx (with SPA fallback) -----------------------------------
FROM nginx:alpine AS admin
COPY --from=builder /project/.webiny/workspace/apps/admin/build /usr/share/nginx/html
COPY nginx-spa.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
