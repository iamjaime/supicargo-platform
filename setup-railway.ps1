# =============================================================================
# SupiCargo — Railway Full-Stack Setup Script
# =============================================================================
# This script creates the entire Fleetbase project on Railway via CLI:
#   - Creates the Railway project
#   - Provisions MySQL and Redis managed databases
#   - Deploys SocketCluster (real-time service) from Docker image
#   - Deploys application, queue, and scheduler from GitHub repo
#   - Deploys the console (admin dashboard) from GitHub repo
#   - Sets ALL environment variables on every service
#   - Generates public domains for console, API, and socket services
#
# Usage:
#   1. Open PowerShell as Administrator (or run: Set-ExecutionPolicy RemoteSigned)
#   2. Run: railway login
#   3. Run: .\setup-railway.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
$GITHUB_REPO    = "iamjaime/supicargo-platform"
$PROJECT_NAME   = "supicargo-platform"

# AWS S3 — fill these in before running!
$AWS_ACCESS_KEY_ID     = Read-Host "Enter your AWS Access Key ID"
$AWS_SECRET_ACCESS_KEY = Read-Host "Enter your AWS Secret Access Key" -AsSecureString
$AWS_SECRET_PLAIN      = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AWS_SECRET_ACCESS_KEY))
$AWS_DEFAULT_REGION    = Read-Host "Enter your AWS region (e.g. us-east-1)"
$AWS_BUCKET            = "supicargo-uploads"

# Google Maps (optional — press Enter to skip for now)
$GOOGLE_MAPS_KEY = Read-Host "Enter Google Maps API Key (press Enter to skip)"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " 🚚  SupiCargo — Railway Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# ─── STEP 1: Create Railway Project ──────────────────────────────────────────
Write-Host "➡️  Step 1: Creating Railway project '$PROJECT_NAME'..." -ForegroundColor Yellow
railway init --name $PROJECT_NAME
Write-Host "✅  Project created" -ForegroundColor Green
Write-Host ""

# ─── STEP 2: Add MySQL Database ──────────────────────────────────────────────
Write-Host "➡️  Step 2: Provisioning MySQL database..." -ForegroundColor Yellow
railway add --database mysql --service database
Write-Host "✅  MySQL provisioned" -ForegroundColor Green
Write-Host ""

# ─── STEP 3: Add Redis Cache ──────────────────────────────────────────────────
Write-Host "➡️  Step 3: Provisioning Redis cache..." -ForegroundColor Yellow
railway add --database redis --service cache
Write-Host "✅  Redis provisioned" -ForegroundColor Green
Write-Host ""

# ─── STEP 4: Deploy SocketCluster (real-time service) ────────────────────────
Write-Host "➡️  Step 4: Deploying SocketCluster (real-time driver tracking)..." -ForegroundColor Yellow
railway add `
  --image "socketcluster/socketcluster:v17.4.0" `
  --service "socket" `
  --variables "SOCKETCLUSTER_WORKERS=2" `
  --variables "SOCKETCLUSTER_BROKERS=1"
Write-Host "✅  SocketCluster deployed" -ForegroundColor Green
Write-Host ""

# ─── STEP 5: Deploy API (application) ────────────────────────────────────────
Write-Host "➡️  Step 5: Deploying Laravel API (application service)..." -ForegroundColor Yellow
railway add `
  --repo $GITHUB_REPO `
  --service "application" `
  --variables "APP_NAME=SupiCargo" `
  --variables "APP_ENV=production" `
  --variables "APP_DEBUG=false" `
  --variables "DB_CONNECTION=mysql" `
  --variables 'DB_HOST=${{database.MYSQLDOMAIN}}' `
  --variables 'DB_PORT=${{database.MYSQLPORT}}' `
  --variables 'DB_DATABASE=${{database.MYSQLDATABASE}}' `
  --variables 'DB_USERNAME=${{database.MYSQLUSER}}' `
  --variables 'DB_PASSWORD=${{database.MYSQLPASSWORD}}' `
  --variables 'REDIS_HOST=${{cache.REDISHOST}}' `
  --variables 'REDIS_PORT=${{cache.REDISPORT}}' `
  --variables 'REDIS_PASSWORD=${{cache.REDISPASSWORD}}' `
  --variables "CACHE_DRIVER=redis" `
  --variables "QUEUE_CONNECTION=redis" `
  --variables "SESSION_DRIVER=redis" `
  --variables "FILESYSTEM_DRIVER=s3" `
  --variables "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" `
  --variables "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_PLAIN" `
  --variables "AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION" `
  --variables "AWS_BUCKET=$AWS_BUCKET" `
  --variables "AWS_URL=https://$AWS_BUCKET.s3.$AWS_DEFAULT_REGION.amazonaws.com" `
  --variables "SOCKETCLUSTER_HOST=socket.railway.internal" `
  --variables "SOCKETCLUSTER_PORT=8000" `
  --variables "BROADCAST_DRIVER=socketcluster" `
  --variables "MAIL_MAILER=log" `
  --variables "LOG_CHANNEL=stderr" `
  --variables "LOG_LEVEL=error" `
  --variables "TRUSTED_PROXIES=*" `
  --variables "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_KEY"
Write-Host "✅  API service created" -ForegroundColor Green
Write-Host ""

# ─── STEP 6: Deploy Queue Worker ──────────────────────────────────────────────
Write-Host "➡️  Step 6: Deploying queue worker..." -ForegroundColor Yellow
railway add `
  --repo $GITHUB_REPO `
  --service "queue" `
  --variables "APP_NAME=SupiCargo" `
  --variables "APP_ENV=production" `
  --variables "APP_DEBUG=false" `
  --variables "DB_CONNECTION=mysql" `
  --variables 'DB_HOST=${{database.MYSQLDOMAIN}}' `
  --variables 'DB_PORT=${{database.MYSQLPORT}}' `
  --variables 'DB_DATABASE=${{database.MYSQLDATABASE}}' `
  --variables 'DB_USERNAME=${{database.MYSQLUSER}}' `
  --variables 'DB_PASSWORD=${{database.MYSQLPASSWORD}}' `
  --variables 'REDIS_HOST=${{cache.REDISHOST}}' `
  --variables 'REDIS_PORT=${{cache.REDISPORT}}' `
  --variables 'REDIS_PASSWORD=${{cache.REDISPASSWORD}}' `
  --variables "CACHE_DRIVER=redis" `
  --variables "QUEUE_CONNECTION=redis" `
  --variables "FILESYSTEM_DRIVER=s3" `
  --variables "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" `
  --variables "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_PLAIN" `
  --variables "AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION" `
  --variables "AWS_BUCKET=$AWS_BUCKET" `
  --variables "LOG_CHANNEL=stderr"
Write-Host "✅  Queue worker created" -ForegroundColor Green
Write-Host ""

# ─── STEP 7: Deploy Scheduler ─────────────────────────────────────────────────
Write-Host "➡️  Step 7: Deploying scheduler..." -ForegroundColor Yellow
railway add `
  --repo $GITHUB_REPO `
  --service "scheduler" `
  --variables "APP_NAME=SupiCargo" `
  --variables "APP_ENV=production" `
  --variables "APP_DEBUG=false" `
  --variables "DB_CONNECTION=mysql" `
  --variables 'DB_HOST=${{database.MYSQLDOMAIN}}' `
  --variables 'DB_PORT=${{database.MYSQLPORT}}' `
  --variables 'DB_DATABASE=${{database.MYSQLDATABASE}}' `
  --variables 'DB_USERNAME=${{database.MYSQLUSER}}' `
  --variables 'DB_PASSWORD=${{database.MYSQLPASSWORD}}' `
  --variables 'REDIS_HOST=${{cache.REDISHOST}}' `
  --variables 'REDIS_PORT=${{cache.REDISPORT}}' `
  --variables 'REDIS_PASSWORD=${{cache.REDISPASSWORD}}' `
  --variables "CACHE_DRIVER=redis" `
  --variables "QUEUE_CONNECTION=redis" `
  --variables "LOG_CHANNEL=stderr"
Write-Host "✅  Scheduler created" -ForegroundColor Green
Write-Host ""

# ─── STEP 8: Deploy Console (Admin Dashboard) ─────────────────────────────────
Write-Host "➡️  Step 8: Deploying admin console (Ember.js dashboard)..." -ForegroundColor Yellow
railway add `
  --repo $GITHUB_REPO `
  --service "console"
Write-Host "✅  Console created" -ForegroundColor Green
Write-Host ""

# ─── STEP 9: Generate Public Domains ──────────────────────────────────────────
Write-Host "➡️  Step 9: Generating public domains..." -ForegroundColor Yellow
railway domain --service "application"
railway domain --service "console"
railway domain --service "socket"
Write-Host "✅  Domains generated" -ForegroundColor Green
Write-Host ""

# ─── STEP 10: Get the generated URLs ──────────────────────────────────────────
Write-Host "➡️  Step 10: Retrieving service URLs..." -ForegroundColor Yellow
$STATUS = railway status --json 2>$null | ConvertFrom-Json

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host " 🎉  SupiCargo Railway setup complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host " ✅  7 services created: database, cache, socket," -ForegroundColor White
Write-Host "     application, queue, scheduler, console" -ForegroundColor White
Write-Host ""
Write-Host " 📋  NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Open your Railway dashboard: railway open" -ForegroundColor White
Write-Host "  2. Check each service's deploy logs for errors" -ForegroundColor White
Write-Host "  3. Once 'application' is running, open its shell:" -ForegroundColor White
Write-Host "     railway shell --service application" -ForegroundColor Yellow
Write-Host "  4. Run the database bootstrap:" -ForegroundColor White
Write-Host "     bash scripts/bootstrap.sh" -ForegroundColor Yellow
Write-Host "  5. Install FleetOps driver dispatch:" -ForegroundColor White
Write-Host "     bash scripts/install-fleetops.sh" -ForegroundColor Yellow
Write-Host "  6. Update APP_URL and SANCTUM_STATEFUL_DOMAINS with your generated URLs" -ForegroundColor White
Write-Host "  7. Update SOCKETCLUSTER_OPTIONS on the socket service with your console URL" -ForegroundColor White
Write-Host ""
Write-Host " 🌐  Open your Railway project:" -ForegroundColor Cyan
cmd /c "railway open"
