const https = require('https');

const TOKEN      = '082bc36b-7b43-45cf-9f63-6a80d537d7c0';
const PROJECT_ID = 'e1f97052-6256-4c2f-a123-023f98656a9f';
const ENV_ID     = '2b382e1b-098c-4c0b-8953-bf48eb47d126';

// Service IDs from the creation run
const SERVICES = {
  application: '31568d2e-1325-43be-b062-c2c2e820f7d2',
  queue:       '8d4f3b22-79a0-4adf-852a-57d8ac4c6a3e',
  scheduler:   '333a8f99-ffad-4c71-a19a-eac98aece8fb',
  console:     '12775fcc-8a9d-48cf-849b-3f57e878bdcf',
};

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
            console.error('  GQL error:', JSON.stringify(parsed.errors));
            reject(new Error(parsed.errors[0].message));
          } else resolve(parsed.data);
        } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function updateServiceInstance(serviceId, settings) {
  return gql(`
    mutation ServiceInstanceUpdate($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) {
      serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input)
    }
  `, {
    serviceId,
    environmentId: ENV_ID,
    input: settings,
  });
}

async function redeploy(serviceId, name) {
  process.stdout.write(`  → Triggering redeploy for "${name}"... `);
  try {
    await gql(`
      mutation ServiceInstanceDeploy($serviceId: String!, $environmentId: String!) {
        serviceInstanceDeploy(serviceId: $serviceId, environmentId: $environmentId)
      }
    `, { serviceId, environmentId: ENV_ID });
    console.log('✅');
  } catch(e) {
    // Redeploy mutation name may differ — not fatal
    console.log(`⚠️  (trigger manually in dashboard)`);
  }
}

async function main() {
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  🔧  SupiCargo — Fixing Railway Service Configuration');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // ── application ─────────────────────────────────────────────────────────────
  process.stdout.write('📦 Fixing "application" (root=api, start=bash deploy.sh)... ');
  await updateServiceInstance(SERVICES.application, {
    rootDirectory:  'api',
    startCommand:   'bash deploy.sh',
    restartPolicyType: 'ON_FAILURE',
    restartPolicyMaxRetries: 5,
  });
  console.log('✅');

  // ── queue ────────────────────────────────────────────────────────────────────
  process.stdout.write('📦 Fixing "queue" (root=api, start=queue:work)... ');
  await updateServiceInstance(SERVICES.queue, {
    rootDirectory: 'api',
    startCommand:  'php artisan queue:work redis --sleep=3 --tries=3 --timeout=90 --max-time=3600',
    restartPolicyType: 'ALWAYS',
  });
  console.log('✅');

  // ── scheduler ────────────────────────────────────────────────────────────────
  process.stdout.write('📦 Fixing "scheduler" (root=api, start=schedule:work)... ');
  await updateServiceInstance(SERVICES.scheduler, {
    rootDirectory: 'api',
    startCommand:  'php artisan schedule:work',
    restartPolicyType: 'ALWAYS',
  });
  console.log('✅');

  // ── console ──────────────────────────────────────────────────────────────────
  process.stdout.write('📦 Fixing "console" (root=console, Dockerfile)... ');
  await updateServiceInstance(SERVICES.console, {
    rootDirectory: 'console',
    startCommand:  "nginx -g 'daemon off;'",
    restartPolicyType: 'ON_FAILURE',
    restartPolicyMaxRetries: 5,
  });
  console.log('✅');

  // ── Trigger redeployments ────────────────────────────────────────────────────
  console.log('\n🔄 Triggering redeployments...');
  await redeploy(SERVICES.application, 'application');
  await redeploy(SERVICES.queue,       'queue');
  await redeploy(SERVICES.scheduler,   'scheduler');
  await redeploy(SERVICES.console,     'console');

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('✅  All service configs updated!');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log('  Service configs applied:');
  console.log('  application  →  rootDir=api  |  start: bash deploy.sh');
  console.log('  queue        →  rootDir=api  |  start: php artisan queue:work');
  console.log('  scheduler    →  rootDir=api  |  start: php artisan schedule:work');
  console.log('  console      →  rootDir=console | start: nginx');
  console.log('\n  Railway will now rebuild each service with the correct settings.');
  console.log('  Watch progress at:');
  console.log(`  https://railway.com/project/e1f97052-6256-4c2f-a123-023f98656a9f\n`);
}

main().catch(err => {
  console.error('\n❌ Error:', err.message);
  process.exit(1);
});
