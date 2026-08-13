const https = require('https');

// ─── CONFIG ───────────────────────────────────────────────────────────────────
const TOKEN       = '082bc36b-7b43-45cf-9f63-6a80d537d7c0';
const PROJECT_ID  = 'e1f97052-6256-4c2f-a123-023f98656a9f';
const ENV_ID      = '2b382e1b-098c-4c0b-8953-bf48eb47d126'; // production
const GITHUB_REPO = 'iamjaime/supicargo-platform';

// Existing service IDs (already created)
const EXISTING = {
  redis:  '02ae00ad-fcac-4434-b38a-4f37ddf27ab6',
  mysql:  '72578b55-99d8-4bf6-9758-e33652395d01',
  socket: '94e204d5-8716-4e14-9b8d-666e6ef619e2',
};

// ─── AWS CONFIG — fill these in ───────────────────────────────────────────────
const AWS_ACCESS_KEY_ID     = process.env.AWS_KEY    || 'REPLACE_WITH_AWS_ACCESS_KEY_ID';
const AWS_SECRET_ACCESS_KEY = process.env.AWS_SECRET || 'REPLACE_WITH_AWS_SECRET_ACCESS_KEY';
const AWS_DEFAULT_REGION    = process.env.AWS_REGION || 'us-east-1';
const AWS_BUCKET            = 'supicargo-uploads';
const AWS_URL               = `https://${AWS_BUCKET}.s3.${AWS_DEFAULT_REGION}.amazonaws.com`;
const GOOGLE_MAPS_API_KEY   = process.env.MAPS_KEY   || '';

// ─── GRAPHQL HELPER ───────────────────────────────────────────────────────────
function gql(query, variables = {}) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ query, variables });
    const req = https.request({
      hostname: 'backboard.railway.com',
      path: '/graphql/v2',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${TOKEN}`,
        'Content-Length': Buffer.byteLength(body),
      },
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.errors) {
            console.error('  GraphQL errors:', JSON.stringify(parsed.errors, null, 2));
            reject(new Error(parsed.errors[0].message));
          } else {
            resolve(parsed.data);
          }
        } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ─── CREATE SERVICE ───────────────────────────────────────────────────────────
async function createService(name, source) {
  process.stdout.write(`  → Creating "${name}" service... `);
  const data = await gql(`
    mutation ServiceCreate($input: ServiceCreateInput!) {
      serviceCreate(input: $input) { id name }
    }
  `, {
    input: {
      projectId: PROJECT_ID,
      name,
      ...(source.image ? { source: { image: source.image } } : {}),
      ...(source.repo  ? { source: { repo:  source.repo  } } : {}),
    }
  });
  const id = data.serviceCreate.id;
  console.log(`✅  id=${id}`);
  return id;
}

// ─── SET VARIABLES ────────────────────────────────────────────────────────────
async function setVars(serviceId, vars) {
  process.stdout.write(`    → Setting ${Object.keys(vars).length} variables... `);
  await gql(`
    mutation VariableCollectionUpsert($input: VariableCollectionUpsertInput!) {
      variableCollectionUpsert(input: $input)
    }
  `, {
    input: {
      projectId: PROJECT_ID,
      environmentId: ENV_ID,
      serviceId,
      variables: vars,
    }
  });
  console.log('✅');
}

// ─── GENERATE DOMAIN ──────────────────────────────────────────────────────────
async function generateDomain(serviceId, name) {
  process.stdout.write(`  → Generating domain for "${name}"... `);
  try {
    const data = await gql(`
      mutation ServiceDomainCreate($input: ServiceDomainCreateInput!) {
        serviceDomainCreate(input: $input) { domain }
      }
    `, { input: { environmentId: ENV_ID, serviceId } });
    const domain = data.serviceDomainCreate.domain;
    console.log(`✅  https://${domain}`);
    return domain;
  } catch (e) {
    console.log(`⚠️  ${e.message}`);
    return null;
  }
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  🚚  SupiCargo — Railway Full Setup (API Mode)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log(`  Project:     supicargo-platform`);
  console.log(`  Environment: production`);
  console.log(`  Existing:    MySQL ✅  Redis ✅  SocketCluster ✅`);
  console.log(`  Creating:    application, queue, scheduler, console\n`);

  // ── Shared vars for API, queue, scheduler ───────────────────────────────────
  const sharedVars = {
    APP_NAME:    'SupiCargo',
    APP_ENV:     'production',
    APP_DEBUG:   'false',
    // Database — references Railway's MySQL service vars
    DB_CONNECTION: 'mysql',
    'DB_HOST':     '${{MySQL.MYSQLDOMAIN}}',
    'DB_PORT':     '${{MySQL.MYSQLPORT}}',
    'DB_DATABASE': '${{MySQL.MYSQLDATABASE}}',
    'DB_USERNAME': '${{MySQL.MYSQLUSER}}',
    'DB_PASSWORD': '${{MySQL.MYSQLPASSWORD}}',
    // Cache — references Railway's Redis service vars
    'REDIS_HOST':     '${{Redis.REDISHOST}}',
    'REDIS_PORT':     '${{Redis.REDISPORT}}',
    'REDIS_PASSWORD': '${{Redis.REDISPASSWORD}}',
    CACHE_DRIVER:   'redis',
    QUEUE_CONNECTION: 'redis',
    SESSION_DRIVER: 'redis',
    // Storage
    FILESYSTEM_DRIVER:    's3',
    AWS_ACCESS_KEY_ID,
    AWS_SECRET_ACCESS_KEY,
    AWS_DEFAULT_REGION,
    AWS_BUCKET,
    AWS_URL,
    // Real-time
    SOCKETCLUSTER_HOST:   'socket.railway.internal',
    SOCKETCLUSTER_PORT:   '8000',
    BROADCAST_DRIVER:     'socketcluster',
    // Mail (disabled until SMTP configured)
    MAIL_MAILER: 'log',
    // Logging
    LOG_CHANNEL: 'stderr',
    LOG_LEVEL:   'error',
    // Security
    TRUSTED_PROXIES: '*',
    // Root dir hint for Railway (API lives in /api subdir)
    RAILWAY_SRC_DIR: 'api',
    ...(GOOGLE_MAPS_API_KEY ? { GOOGLE_MAPS_API_KEY } : {}),
  };

  // ── 1. application service ──────────────────────────────────────────────────
  console.log('📦 Service 1/4: application (Laravel API)');
  const appId = await createService('application', { repo: GITHUB_REPO });
  await setVars(appId, {
    ...sharedVars,
    // Pre-deploy will run migrations on first boot
    RAILWAY_RUN_UID: '0',
  });
  await sleep(500);

  // ── 2. queue service ────────────────────────────────────────────────────────
  console.log('\n📦 Service 2/4: queue (background worker)');
  const queueId = await createService('queue', { repo: GITHUB_REPO });
  await setVars(queueId, {
    ...sharedVars,
    RAILWAY_SRC_DIR: 'api',
  });
  await sleep(500);

  // ── 3. scheduler service ────────────────────────────────────────────────────
  console.log('\n📦 Service 3/4: scheduler (cron tasks)');
  const schedulerId = await createService('scheduler', { repo: GITHUB_REPO });
  await setVars(schedulerId, {
    ...sharedVars,
    RAILWAY_SRC_DIR: 'api',
  });
  await sleep(500);

  // ── 4. console service ──────────────────────────────────────────────────────
  console.log('\n📦 Service 4/4: console (Ember.js admin dashboard)');
  const consoleId = await createService('console', { repo: GITHUB_REPO });
  await sleep(500);

  // ── Domains ─────────────────────────────────────────────────────────────────
  console.log('\n🌐 Generating public domains...');
  const apiDomain     = await generateDomain(appId,     'application');
  const consoleDomain = await generateDomain(consoleId, 'console');
  const socketDomain  = await generateDomain(EXISTING.socket, 'socket');
  await sleep(500);

  // ── Update cross-service references ─────────────────────────────────────────
  if (apiDomain) {
    process.stdout.write('\n🔗 Updating application with its own URL... ');
    await setVars(appId, {
      APP_URL: `https://${apiDomain}`,
      SANCTUM_STATEFUL_DOMAINS: consoleDomain ? consoleDomain : '',
      CORS_ALLOWED_ORIGINS: consoleDomain ? `https://${consoleDomain}` : '',
    });
    console.log('✅');
  }

  if (consoleDomain && apiDomain) {
    process.stdout.write('🔗 Updating console with API + socket URLs... ');
    await setVars(consoleId, {
      API_HOST:           `https://${apiDomain}`,
      SOCKETCLUSTER_HOST: socketDomain ? `wss://${socketDomain}` : 'socket.railway.internal',
    });
    console.log('✅');
  }

  if (socketDomain && consoleDomain) {
    process.stdout.write('🔗 Updating socket CORS origins... ');
    await setVars(EXISTING.socket, {
      SOCKETCLUSTER_OPTIONS: JSON.stringify({ origins: `https://${consoleDomain}:*` }),
    });
    console.log('✅');
  }

  // ── Done ────────────────────────────────────────────────────────────────────
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🎉  All 7 services are now provisioned on Railway!');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log('  Services:');
  console.log('  ✅  MySQL       (database)');
  console.log('  ✅  Redis       (cache)');
  console.log('  ✅  socket      (real-time)');
  console.log('  ✅  application (Laravel API)');
  console.log('  ✅  queue       (worker)');
  console.log('  ✅  scheduler   (cron)');
  console.log('  ✅  console     (admin dashboard)');
  console.log('\n  URLs:');
  if (apiDomain)     console.log(`  🔗 API:     https://${apiDomain}`);
  if (consoleDomain) console.log(`  🖥️  Console: https://${consoleDomain}`);
  if (socketDomain)  console.log(`  🔌 Socket:  wss://${socketDomain}`);
  console.log(`\n  📊 Project dashboard:`);
  console.log(`     https://railway.com/project/${PROJECT_ID}`);
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('\n📋 IMPORTANT — Manual steps still needed:');
  console.log('\n  1. Set ROOT DIRECTORY for each GitHub service in Railway dashboard:');
  console.log('     → application, queue, scheduler: Root Directory = "api"');
  console.log('     → console:                       Root Directory = "console"');
  console.log('\n  2. Set START COMMANDS in Railway dashboard:');
  console.log('     → application: bash deploy.sh');
  console.log('     → queue:       php artisan queue:work redis --sleep=3 --tries=3');
  console.log('     → scheduler:   php artisan schedule:work');
  console.log('\n  3. Once "application" is running, add your AWS credentials:');
  console.log('     (The script set placeholder values — update in Variables tab)');
  console.log('\n  4. Open the Railway shell on "application" and run:');
  console.log('     bash scripts/bootstrap.sh');
  console.log('     bash scripts/install-fleetops.sh');
  console.log('');
}

main().catch(err => {
  console.error('\n❌ Fatal error:', err.message);
  process.exit(1);
});
