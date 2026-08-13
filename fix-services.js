const https = require('https');

const TOKEN      = '082bc36b-7b43-45cf-9f63-6a80d537d7c0';
const PROJECT_ID = 'e1f97052-6256-4c2f-a123-023f98656a9f';
const ENV_ID     = '2b382e1b-098c-4c0b-8953-bf48eb47d126';

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
      res.on('data', c => data += c);
      res.on('end', () => {
        try {
          const p = JSON.parse(data);
          if (p.errors) { console.error('  GQL:', JSON.stringify(p.errors)); reject(new Error(p.errors[0].message)); }
          else resolve(p.data);
        } catch(e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// Update instance settings (start command, root dir, restart policy)
async function updateInstance(serviceId, input) {
  return gql(`
    mutation ServiceInstanceUpdate($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) {
      serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input)
    }
  `, { serviceId, environmentId: ENV_ID, input });
}

// Update service-level source/build config (Dockerfile path, watch patterns)
async function updateServiceSource(serviceId, input) {
  return gql(`
    mutation ServiceUpdate($id: String!, $input: ServiceUpdateInput!) {
      serviceUpdate(id: $id, input: $input) { id name }
    }
  `, { id: serviceId, input });
}

async function redeploy(serviceId, name) {
  process.stdout.write(`  → Redeploying "${name}"... `);
  try {
    await gql(`
      mutation ServiceInstanceDeploy($serviceId: String!, $environmentId: String!) {
        serviceInstanceDeploy(serviceId: $serviceId, environmentId: $environmentId)
      }
    `, { serviceId, environmentId: ENV_ID });
    console.log('✅');
  } catch(e) { console.log(`⚠️  ${e.message}`); }
}

async function main() {
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  🔧  SupiCargo — Fixing Build Context & Docker Targets');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // ── application ─────────────────────────────────────────────────────────────
  process.stdout.write('📦 application (rootDir=repo root, start=octane)... ');
  await updateInstance(SERVICES.application, {
    rootDirectory: '',
    startCommand: 'php artisan octane:frankenphp --max-requests=1000 --port=${PORT:-8000} --host=0.0.0.0',
    restartPolicyType: 'ON_FAILURE',
    restartPolicyMaxRetries: 5,
  });
  console.log('✅');

  // ── queue ────────────────────────────────────────────────────────────────────
  process.stdout.write('📦 queue       (rootDir=repo root, start=queue:work)... ');
  await updateInstance(SERVICES.queue, {
    rootDirectory: '',
    startCommand: 'php artisan queue:work redis --sleep=3 --tries=3 --timeout=90 --max-time=3600',
    restartPolicyType: 'ALWAYS',
  });
  console.log('✅');

  // ── scheduler ────────────────────────────────────────────────────────────────
  process.stdout.write('📦 scheduler   (rootDir=repo root, start=schedule:work)... ');
  await updateInstance(SERVICES.scheduler, {
    rootDirectory: '',
    startCommand: 'php artisan schedule:work',
    restartPolicyType: 'ALWAYS',
  });
  console.log('✅');

  // ── console stays at rootDir=console ─────────────────────────────────────────
  process.stdout.write('📦 console     (rootDir=console, nginx)... ');
  await updateInstance(SERVICES.console, {
    rootDirectory: 'console',
    startCommand: "nginx -g 'daemon off;'",
    restartPolicyType: 'ON_FAILURE',
    restartPolicyMaxRetries: 5,
  });
  console.log('✅');

  // ── Trigger redeployments ─────────────────────────────────────────────────────
  console.log('\n🔄 Triggering redeployments...');
  await redeploy(SERVICES.application, 'application');
  await redeploy(SERVICES.queue,       'queue');
  await redeploy(SERVICES.scheduler,   'scheduler');
  await redeploy(SERVICES.console,     'console');

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('✅  Done! Builds starting now (~8-10 min for PHP image).');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log('  The railway.toml at repo root tells Railway to use:');
  console.log('  dockerfilePath = "docker/Dockerfile"');
  console.log('  This gives the Dockerfile access to ./api/ and ./Caddyfile');
  console.log('  and uses PHP 8.2 (frankenphp:1.12.4-php8.2-bookworm)\n');
  console.log(`  Watch: https://railway.com/project/${PROJECT_ID}\n`);
}

main().catch(err => { console.error('\n❌', err.message); process.exit(1); });
