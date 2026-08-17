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

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Nginx listens on Railway's dynamic $PORT
EXPOSE 8080

# At startup:
# 1. Write fleetbase.config.json using the API_HOST env var (set in Railway Variables)
# 2. Replace the PORT placeholder in the nginx config
# 3. Start nginx
CMD ["/bin/sh", "-c", "\
  echo \"{\\\"API_HOST\\\":\\\"${API_HOST}\\\",\\\"SOCKETCLUSTER_HOST\\\":\\\"${SOCKETCLUSTER_HOST}\\\",\\\"SOCKETCLUSTER_PORT\\\":443,\\\"SOCKETCLUSTER_SECURE\\\":true}\" > /usr/share/nginx/html/fleetbase.config.json && \
  sed -i \"s/\\${PORT}/${PORT:-80}/g\" /etc/nginx/conf.d/default.conf && \
  nginx -g 'daemon off;' \
"]
