#!/usr/bin/env bash
# =============================================================================
# SupiCargo — Fleetbase Database Bootstrap Script
# =============================================================================
# Run this ONCE after your Railway services are deployed and the DB is live.
# Execute via Railway's built-in Shell on the 'application' service, or as
# a Railway Pre-Deploy command on first deploy.
#
# Usage (local with Railway CLI):
#   railway shell   # opens a shell into the application container
#   bash /app/scripts/bootstrap.sh
#
# Usage (Pre-Deploy command — Railway dashboard):
#   bash scripts/bootstrap.sh
# =============================================================================

set -euo pipefail

echo ""
echo "🚀  SupiCargo — Fleetbase Bootstrap"
echo "====================================="
echo ""

# ─── STEP 1: Generate Application Key ─────────────────────────────────────────
echo "➡️  Step 1: Generating application encryption key..."
php artisan key:generate --force
echo "✅  APP_KEY generated and set"

# ─── STEP 2: Run Database Migrations ─────────────────────────────────────────
echo ""
echo "➡️  Step 2: Running database migrations..."
php artisan migrate --force
echo "✅  Migrations complete"

# ─── STEP 3: Seed Database ────────────────────────────────────────────────────
echo ""
echo "➡️  Step 3: Seeding initial data (roles, permissions, system defaults)..."
php artisan db:seed --force
echo "✅  Database seeded"

# ─── STEP 4: Cache Configuration ─────────────────────────────────────────────
echo ""
echo "➡️  Step 4: Caching configuration for production performance..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
echo "✅  Config, routes, and views cached"

# ─── STEP 5: Create Storage Symlink ──────────────────────────────────────────
echo ""
echo "➡️  Step 5: Creating storage symlink..."
php artisan storage:link || true
echo "✅  Storage symlink created"

# ─── STEP 6: Optimize ─────────────────────────────────────────────────────────
echo ""
echo "➡️  Step 6: Running final optimization..."
php artisan optimize
echo "✅  Application optimized"

# ─── DONE ─────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉  Bootstrap complete! Fleetbase is ready."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋  Your next step:"
echo "    1. Open your Console URL in a browser"
echo "    2. Use the default admin credentials printed during seeding"
echo "    3. Immediately change the admin password in Settings → Profile"
echo ""
