#!/usr/bin/env bash
# =============================================================================
# SupiCargo — FleetOps Extension Installer
# =============================================================================
# Installs the FleetOps driver dispatch extension into Fleetbase.
# Run this AFTER bootstrap.sh completes successfully.
#
# FleetOps adds:
#   - Driver management & GPS tracking
#   - Order dispatch & assignment
#   - Fleet vehicle management
#   - Route optimization
#   - Delivery proof of delivery (POD)
#   - Driver mobile app (Fleetbase Navigator) integration
#
# Usage:
#   railway shell   # (in the application service)
#   bash /app/scripts/install-fleetops.sh
# =============================================================================

set -euo pipefail

echo ""
echo "🚚  SupiCargo — FleetOps Extension Installer"
echo "=============================================="
echo ""

# ─── STEP 1: Install FleetOps API package ─────────────────────────────────────
echo "➡️  Step 1: Installing FleetOps API package via Composer..."
composer require fleetbase/fleetops-api --no-interaction --prefer-dist
echo "✅  FleetOps API package installed"

# ─── STEP 2: Publish package assets & config ─────────────────────────────────
echo ""
echo "➡️  Step 2: Publishing FleetOps service provider assets..."
php artisan vendor:publish \
  --provider="Fleetbase\FleetOps\Providers\FleetOpsServiceProvider" \
  --force
echo "✅  Assets published"

# ─── STEP 3: Run FleetOps migrations ─────────────────────────────────────────
echo ""
echo "➡️  Step 3: Running FleetOps database migrations..."
php artisan migrate --force
echo "✅  FleetOps tables created"

# ─── STEP 4: Seed FleetOps defaults ──────────────────────────────────────────
echo ""
echo "➡️  Step 4: Seeding FleetOps default data..."
php artisan db:seed --class=FleetOpsSeeder --force || true
echo "✅  FleetOps defaults seeded"

# ─── STEP 5: Clear and rebuild caches ─────────────────────────────────────────
echo ""
echo "➡️  Step 5: Refreshing application caches..."
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan config:cache
php artisan route:cache
echo "✅  Caches refreshed"

# ─── DONE ─────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉  FleetOps installed! Driver dispatch is ready."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋  What to do next:"
echo "    1. In the Admin Console, navigate to FleetOps → Drivers"
echo "    2. Add your warehouse location under FleetOps → Locations"
echo "    3. Create vehicle records under FleetOps → Fleet"
echo "    4. Your drivers should download 'Fleetbase Navigator' from the App Store / Google Play"
echo "    5. Share your SupiCargo organization slug with drivers to connect"
echo ""
echo "🗺️  For live map tracking, set GOOGLE_MAPS_API_KEY in your Railway env vars"
echo "    Get a key at: https://console.cloud.google.com/apis/credentials"
echo "    Enable: Maps JavaScript API, Geocoding API, Directions API"
echo ""
