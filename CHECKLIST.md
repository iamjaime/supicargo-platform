# SupiCargo — Railway Deployment Checklist

Complete each step in order. Check off as you go.

---

## 🔵 STEP 0 — Prerequisites

- [ ] **Fork Fleetbase on GitHub**
  - Go to https://github.com/fleetbase/fleetbase
  - Click **Fork** → fork into your GitHub account
  - Recommended fork name: `supicargo-platform`

- [ ] **Clone your fork locally**
  ```bash
  git clone https://github.com/YOUR_GITHUB_USER/supicargo-platform.git
  cd supicargo-platform
  ```

- [ ] **Copy this deployment package into your fork**
  ```bash
  # Copy the contents of fleetbase-railway/ into the root of your fork
  cp -r /path/to/fleetbase-railway/* .
  git add .
  git commit -m "chore: add Railway deployment configuration"
  git push origin main
  ```

- [ ] **Install Railway CLI**
  ```bash
  npm install -g @railway/cli
  railway login
  ```

- [ ] **Run the AWS S3 setup script**
  ```bash
  cd aws/
  chmod +x setup-s3.sh
  ./setup-s3.sh
  # This creates: s3://supicargo-uploads bucket with correct CORS & permissions
  # Note the output — you'll need the bucket name & region for env vars
  ```

---

## 🟡 STEP 1 — Create Railway Project & Managed Services

### 1.1 Create a New Project

1. Go to https://railway.app/dashboard
2. Click **New Project**
3. Select **Empty Project**
4. Name it: `supicargo-platform`

### 1.2 Add MySQL Database

1. Inside the project, click **+ New Service**
2. Select **Database** → **MySQL**
3. Wait for it to provision (30–60 seconds)
4. Click on the MySQL service → **Variables** tab
5. Note these values for later (Railway auto-generates them):
   - `MYSQLDOMAIN` (internal hostname)
   - `MYSQLPORT`
   - `MYSQLDATABASE`
   - `MYSQLUSER`
   - `MYSQLPASSWORD`

### 1.3 Add Redis Cache

1. Click **+ New Service** → **Database** → **Redis**
2. Wait for it to provision
3. Click on Redis → **Variables** tab, note:
   - `REDISHOST`
   - `REDISPORT`
   - `REDISPASSWORD`

---

## 🟠 STEP 2 — Deploy SocketCluster (Real-Time Service)

1. Click **+ New Service** → **Docker Image**
2. Enter image: `socketcluster/socketcluster:v17.4.0`
3. Name the service: `socket`
4. Go to **Variables** tab and add:
   ```
   SOCKETCLUSTER_WORKERS=2
   SOCKETCLUSTER_BROKERS=1
   ```
5. Go to **Settings** → **Networking** → **Generate Domain** (this creates your public WebSocket URL)
6. Copy the generated domain — you'll need it as `SOCKETCLUSTER_HOST` for the API

---

## 🟤 STEP 3 — Deploy the API (application service)

### 3.1 Connect GitHub Repo

1. Click **+ New Service** → **GitHub Repo**
2. Connect your GitHub account if not already connected
3. Select your `supicargo-platform` fork
4. Name the service: `application`
5. Under **Settings** → **Root Directory**, set it to: `/api`
   > (Or leave empty if the Fleetbase repo root contains the API Dockerfile)

### 3.2 Add API Configuration

1. In the service **Settings** → **Build**, set:
   - **Builder**: `Dockerfile`
   - **Dockerfile Path**: `Dockerfile`

2. Under **Settings** → **Deploy**:
   - **Start Command**: `bash start.sh`
   - **Health Check Path**: `/api/v1/health-check`
   - **Pre-Deploy Command**: `php artisan migrate --force && php artisan db:seed --force`

   > ⚠️ The Pre-Deploy command runs ONCE on first deploy to initialize the database.
   > After first successful deploy, you can remove or disable this.

### 3.3 Set Environment Variables

1. Go to **Variables** tab → click **Raw Editor**
2. Copy the contents of `env.template`, fill in your values, and paste them in
3. Use Railway's variable reference syntax for managed services:
   ```
   DB_HOST=${{MySQL.MYSQLDOMAIN}}
   DB_PASSWORD=${{MySQL.MYSQLPASSWORD}}
   REDIS_HOST=${{Redis.REDISHOST}}
   ```
4. Click **Generate Domain** in Settings → Networking to get your API URL

---

## 🔵 STEP 4 — Deploy the Console (Admin Dashboard)

1. Click **+ New Service** → **GitHub Repo** → same fork
2. Name the service: `console`
3. Under **Settings** → **Root Directory**, set to: `/console`
4. Add environment variables:
   ```
   API_HOST=https://<your-application-railway-url>
   SOCKETCLUSTER_HOST=wss://<your-socket-railway-url>
   ```
5. Click **Generate Domain** — this is the URL your team will use to log in

---

## 🟢 STEP 5 — Deploy Queue Worker

1. Click **+ New Service** → **GitHub Repo** → same fork
2. Name the service: `queue`
3. **Root Directory**: same as API (`/api`)
4. **Start Command**: `php artisan queue:work --sleep=3 --tries=3 --timeout=90`
5. Copy **all the same environment variables** from the `application` service
   - Tip: Use Railway's **Shared Variables** under Project Settings to avoid duplication

---

## 🟣 STEP 6 — Deploy Scheduler

1. Click **+ New Service** → **GitHub Repo** → same fork
2. Name the service: `scheduler`
3. **Root Directory**: same as API (`/api`)
4. **Start Command**: `php artisan schedule:work`
5. Copy the same environment variables as queue/application

---

## ⚫ STEP 7 — Install FleetOps Extension

SSH into or use Railway's **Shell** feature on the `application` service:

```bash
# Run inside the application container
chmod +x /app/scripts/install-fleetops.sh
bash /app/scripts/install-fleetops.sh
```

Or run the install command directly:
```bash
composer require fleetbase/fleetops-api
php artisan vendor:publish --provider="Fleetbase\FleetOps\Providers\FleetOpsServiceProvider"
php artisan migrate --force
```

---

## ✅ STEP 8 — Verify Everything Works

Run the health check script:
```bash
chmod +x scripts/healthcheck.sh
./scripts/healthcheck.sh
```

Manual checks:
- [ ] Open the Console URL → login page appears
- [ ] Log in with default admin credentials (check bootstrap output)
- [ ] Navigate to **FleetOps** → Driver section
- [ ] Create a test driver and assign an order
- [ ] Confirm real-time map shows driver location updates
- [ ] Upload a test file → confirm it appears in your S3 bucket

---

## 🎉 You're Live!

Your SupiCargo platform is now running. Share the Console URL with your dispatch team.

**Next steps to consider:**
- Purchase a domain and attach it to Railway (console + API services)
- Configure push notifications for the driver mobile app (Fleetbase Navigator)
- Set up email (SendGrid/Resend) for order confirmation emails
- Invite your team members via Settings → Organization → Members
