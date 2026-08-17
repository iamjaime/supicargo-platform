#!/bin/sh

# Exit the script as soon as a command fails
set -e

# Create mysql databases if none exists
php artisan mysql:createdb

# Run migrations
php artisan migrate --force

# Run migrations for sandbox too
php artisan sandbox:migrate --force

# Seed database
php artisan fleetbase:seed

# Create permissions, policies, and roles
php artisan fleetbase:create-permissions

# Restart queue
php artisan queue:restart

# Sync scheduler
php artisan schedule-monitor:sync

# Clear all caches so dynamic routes and env vars resolve at runtime
php artisan cache:clear
php artisan route:clear
php artisan config:clear
php artisan view:clear

# Initialize registry
php artisan registry:init

# Notify open install pages that setup has completed
php artisan fleetbase:notify-installed || true

# Start Octane / FrankenPHP web server on Railway's dynamic PORT
PORT="${PORT:-80}"
echo "Starting Octane FrankenPHP on port $PORT..."
exec php artisan octane:frankenphp --max-requests=1000 --port="${PORT}" --host=0.0.0.0
