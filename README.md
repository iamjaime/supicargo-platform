# SupiCargo — Fleetbase on Railway
> Authorized Servientrega Delivery Partner | Colombia Operations Platform

This directory contains everything you need to deploy **Fleetbase** (with the **FleetOps** driver dispatch extension) onto **Railway.app**.

---

## 📁 Repository Structure

```
fleetbase-railway/
├── README.md                  ← You are here
├── CHECKLIST.md               ← Step-by-step Railway setup steps
├── env.template               ← All environment variables (fill in and paste into Railway)
├── docker-compose.override.yml← Production overrides (for local testing against Railway DBs)
│
├── railway/
│   ├── api.railway.toml       ← API (Laravel) service config
│   ├── console.railway.toml   ← Console (Ember.js) service config
│   ├── queue.railway.toml     ← Queue worker service config
│   ├── scheduler.railway.toml ← Scheduler service config
│   └── socket.railway.toml    ← SocketCluster real-time service config
│
├── aws/
│   ├── s3-bucket-policy.json  ← IAM policy for delivery photo uploads
│   └── setup-s3.sh            ← AWS CLI script to create & configure S3 bucket
│
└── scripts/
    ├── bootstrap.sh           ← One-time: DB migrations + seed
    ├── install-fleetops.sh    ← Install FleetOps driver dispatch extension
    └── healthcheck.sh         ← Verify all Railway services are alive
```

---

## 🏗️ Architecture

Fleetbase runs as **7 Railway services** inside one Railway project:

| Service | Image/Source | Purpose | Public? |
|---|---|---|---|
| `application` | GitHub repo `/api` | Laravel REST API | ✅ Yes (`/api/*`) |
| `console` | GitHub repo `/console` | Ember.js admin dashboard | ✅ Yes |
| `socket` | `socketcluster/socketcluster:v17.4.0` | Real-time driver tracking | ✅ Yes (WebSocket) |
| `database` | Railway MySQL 8 plugin | Primary datastore | ❌ Internal only |
| `cache` | Railway Redis plugin | Sessions, queues, cache | ❌ Internal only |
| `queue` | Same as `application` | Background jobs | ❌ Internal only |
| `scheduler` | Same as `application` | Cron tasks | ❌ Internal only |

---

## 🚀 Quick Start

### Prerequisites
- [ ] Railway account at [railway.app](https://railway.app) (Pro plan recommended)
- [ ] GitHub account with a **fork** of `github.com/fleetbase/fleetbase`
- [ ] Railway CLI installed: `npm install -g @railway/cli`
- [ ] AWS CLI configured with your credentials
- [ ] This folder's files added to your Fleetbase fork

### Estimated setup time: 45–90 minutes

See **[CHECKLIST.md](./CHECKLIST.md)** for the full step-by-step walkthrough.

---

## 🔑 Key URLs (after deployment)

| What | URL Pattern |
|---|---|
| Admin Dashboard | `https://console-<hash>.up.railway.app` |
| API | `https://application-<hash>.up.railway.app` |
| WebSocket | `wss://socket-<hash>.up.railway.app` |

> **Note:** Railway generates URLs like `service-hash.up.railway.app` automatically. 
> Once you purchase a domain, you can attach it in Railway → Service → Settings → Custom Domain.

---

## 📦 What FleetOps Adds

The FleetOps extension (installed via `scripts/install-fleetops.sh`) adds:

- 🗺️ **Live driver map** with GPS tracking
- 📋 **Order dispatch** and assignment to drivers
- 🚗 **Fleet vehicle management** (registration, status, maintenance)
- 📱 **Driver mobile app** (Fleetbase Navigator — available on iOS/Android)
- 🔔 **Push notifications** to drivers
- 📊 **Delivery analytics** (completion rates, ETAs, distances)
- 🗓️ **Route scheduling** and optimization

---

## 🆘 Support

- Fleetbase Docs: https://docs.fleetbase.io
- Fleetbase Discord: https://discord.gg/fleetbase
- Railway Docs: https://docs.railway.app
- Railway Discord: https://discord.gg/railway
