#!/bin/sh

# Run migrations if needed
php artisan migrate --force || true
php artisan sandbox:migrate --force || true

# Clear all caches so dynamic routes and env vars resolve at runtime
php artisan cache:clear || true
php artisan route:clear || true
php artisan config:clear || true
php artisan view:clear || true

# Start Octane / FrankenPHP web server on Railway's dynamic PORT
PORT="${PORT:-80}"
echo "Starting Octane FrankenPHP on port $PORT..."
exec php artisan octane:frankenphp --max-requests=1000 --port="${PORT}" --admin-port=2019 --host=0.0.0.0
