# syntax=docker/dockerfile:1
#
# Multi-stage build for Webiny standalone (self-hosted).
# Targets: api (Node.js) and admin (Nginx SPA).

# --- builder: produce the self-contained build/ folders -----------------------------------------
FROM node:24-bookworm AS builder
WORKDIR /project
ENV WEBINY_HOSTING_TYPE=standalone NODE_ENV=production
COPY . .
RUN corepack enable && yarn install --immutable

# The Admin bundle bakes its API origin at build time.
ARG WEBINY_API_URL=http://localhost:3002
ENV WEBINY_API_URL=$WEBINY_API_URL

RUN yarn webiny build api && yarn webiny build admin

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
