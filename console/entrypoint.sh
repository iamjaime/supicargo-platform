#!/bin/sh
set -e

PORT="${PORT:-80}"
API_HOST="${API_HOST:-https://application-production-919c.up.railway.app}"
SOCKETCLUSTER_HOST="${SOCKETCLUSTER_HOST:-console-production-0f5e.up.railway.app}"
SOCKETCLUSTER_PATH="${SOCKETCLUSTER_PATH:-/socketcluster/}"
SOCKETCLUSTER_PORT="${SOCKETCLUSTER_PORT:-443}"
SOCKETCLUSTER_SECURE="${SOCKETCLUSTER_SECURE:-true}"

echo "Starting Fleetbase Console..."
echo "  API_HOST: ${API_HOST}"
echo "  SOCKETCLUSTER_HOST: ${SOCKETCLUSTER_HOST}"
echo "  PORT: ${PORT}"

# Write the runtime config so the Ember app knows where the API and WebSocket live.
cat > /usr/share/nginx/html/fleetbase.config.json << EOF
{"API_HOST":"${API_HOST}","SOCKETCLUSTER_HOST":"${SOCKETCLUSTER_HOST}","SOCKETCLUSTER_PORT":${SOCKETCLUSTER_PORT},"SOCKETCLUSTER_SECURE":${SOCKETCLUSTER_SECURE},"SOCKETCLUSTER_PATH":"${SOCKETCLUSTER_PATH}"}
EOF

echo "  Config written: $(cat /usr/share/nginx/html/fleetbase.config.json)"

# Substitute the PORT placeholder in the nginx config
sed -i "s/\${PORT}/${PORT}/g" /etc/nginx/conf.d/default.conf

# Start nginx
exec nginx -g 'daemon off;'
