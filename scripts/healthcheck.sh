#!/usr/bin/env bash
# =============================================================================
# SupiCargo — Railway Services Health Check
# =============================================================================
# Verifies that all Railway services are up and responding correctly.
# Run this after deployment to confirm everything is working.
#
# Usage:
#   chmod +x healthcheck.sh
#   ./healthcheck.sh
#
# Prerequisites:
#   - Your Railway service URLs (replace the placeholders below)
#   - curl installed
# =============================================================================

set -euo pipefail

# ─── CONFIGURE YOUR URLS HERE ─────────────────────────────────────────────────
# Replace these with your actual Railway-generated URLs
API_URL="${API_URL:-https://YOUR_APPLICATION_RAILWAY_URL}"
CONSOLE_URL="${CONSOLE_URL:-https://YOUR_CONSOLE_RAILWAY_URL}"
SOCKET_URL="${SOCKET_URL:-https://YOUR_SOCKET_RAILWAY_URL}"

# ─── COLORS ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

check() {
  local name="$1"
  local url="$2"
  local expected_code="${3:-200}"

  printf "  Checking %-30s " "$name..."
  
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  
  if [ "$http_code" = "$expected_code" ] || [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
    echo -e "${GREEN}✅  HTTP $http_code${NC}"
    ((PASS++))
  else
    echo -e "${RED}❌  HTTP $http_code (expected $expected_code)${NC}"
    ((FAIL++))
  fi
}

echo ""
echo "🏥  SupiCargo — Fleetbase Health Check"
echo "======================================="
echo ""

echo "🌐 Public Services:"
check "API Health Endpoint"        "$API_URL/api/v1/health-check"
check "Console Dashboard"          "$CONSOLE_URL"
check "SocketCluster HTTP"         "$SOCKET_URL/health"

echo ""
echo "🔌 API Endpoints:"
check "API Root"                   "$API_URL/api"                    "200"
check "API Auth Route"             "$API_URL/api/v1/auth/sign-in"    "405"

echo ""

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}🎉  All checks passed! ($PASS/$((PASS+FAIL)))${NC}"
else
  echo -e "${YELLOW}⚠️   $PASS passed, $FAIL failed${NC}"
  echo ""
  echo "Troubleshooting tips:"
  echo "  - Check Railway dashboard → each service → Deployments tab for errors"
  echo "  - View logs: railway logs -s <service-name>"
  echo "  - Verify environment variables are set correctly"
  echo "  - Make sure DB migrations ran: railway shell → php artisan migrate:status"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
