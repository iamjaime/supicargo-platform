# ---- Build Stage ----
FROM node:22.22.0-alpine3.22 AS builder

# Set the working directory in the container to /console
WORKDIR /console

# Create the pnpm directory and set the PNPM_HOME environment variable
RUN mkdir -p ~/.pnpm
ENV PNPM_HOME=/root/.pnpm

# Set environment
ARG ENVIRONMENT=production

# Attribution
ARG DISABLE_FLEETBASE_ATTRIBUTION=false
ENV DISABLE_FLEETBASE_ATTRIBUTION=$DISABLE_FLEETBASE_ATTRIBUTION

# API configuration — baked into the Ember JS bundle at build time.
# Railway passes service variables as build args when declared here.
# See console/config/environment.js — getenv('API_HOST') reads process.env at build time.
# DISABLE_RUNTIME_CONFIG defaults to true in production, so fleetbase.config.json is ignored;
# the API URL must come from these build-time env vars instead.
ARG API_HOST
ARG API_SECURE=true
ARG API_NAMESPACE=int/v1
ARG SOCKETCLUSTER_HOST
ARG SOCKETCLUSTER_PORT=443
ARG SOCKETCLUSTER_SECURE=true
ARG SOCKETCLUSTER_PATH=/socketcluster/
ENV API_HOST=$API_HOST
ENV API_SECURE=$API_SECURE
ENV API_NAMESPACE=$API_NAMESPACE
ENV SOCKETCLUSTER_HOST=$SOCKETCLUSTER_HOST
ENV SOCKETCLUSTER_PORT=$SOCKETCLUSTER_PORT
ENV SOCKETCLUSTER_SECURE=$SOCKETCLUSTER_SECURE
ENV SOCKETCLUSTER_PATH=$SOCKETCLUSTER_PATH

# Add the pnpm global bin to the PATH
ENV PATH=/root/.pnpm/bin:$PATH

# Copy package metadata first for better dependency caching
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Copy over .npmrc if applicable
COPY .npmr[c] ./

# Install global dependencies
RUN npm install -g ember-cli pnpm 

# Install git
RUN apk update && apk add git openssh-client

# Trust GitHub's RSA host key
RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts

# Install app dependencies
RUN pnpm install --frozen-lockfile

# Copy the console directory contents into the container at /console
COPY . .

# Build the application
RUN pnpm build --environment $ENVIRONMENT

# ---- Serve Stage ----
FROM nginx:alpine

# Copy the built app to our served directory
COPY --from=builder /console/dist /usr/share/nginx/html

# Copy nginx config (uses ${PORT} placeholder, replaced by entrypoint.sh)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy startup script — writes fleetbase.config.json from env vars, then starts nginx
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]

