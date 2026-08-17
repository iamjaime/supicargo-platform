#!/bin/sh
set -e

PORT="${PORT:-80}"
API_HOST="${API_HOST:-http://localhost:8000}"
SOCKETCLUSTER_HOST="${SOCKETCLUSTER_HOST:-}"

echo "Starting Fleetbase Console..."
echo "  API_HOST: ${API_HOST}"
echo "  SOCKETCLUSTER_HOST: ${SOCKETCLUSTER_HOST}"
echo "  PORT: ${PORT}"

# Write the runtime config so the Ember app knows where the API lives.
# This overwrites the localhost:8000 default that ships with the build.
cat > /usr/share/nginx/html/fleetbase.config.json << EOF
{"API_HOST":"${API_HOST}","SOCKETCLUSTER_HOST":"${SOCKETCLUSTER_HOST}","SOCKETCLUSTER_PORT":443,"SOCKETCLUSTER_SECURE":true}
EOF

echo "  Config written: $(cat /usr/share/nginx/html/fleetbase.config.json)"

# Substitute the PORT placeholder in the nginx config
sed -i "s/\${PORT}/${PORT}/g" /etc/nginx/conf.d/default.conf

# Start nginx
exec nginx -g 'daemon off;'
