/**
 * PM2 Production Process Orchestration Configuration for SvelteKit Starter
 */
const fs = require('fs');
const path = require('path');

// Safely load .env without external dependencies
const loadedEnv = {};

try {
  const possiblePaths = [
    process.env.ENV_FILE,
    process.env.CONFIG_DIR ? path.join(process.env.CONFIG_DIR, '.env') : null,
    path.resolve(__dirname, '.env'),
    '/home/deploy/configs/starter-template/.env',
    '/home/deploy/configs/starter-template.env',
    '/home/deploy/configs/starter-template',
    '/home/deploy/configs/.env',
    '/home/deploy/config/starter-template/.env',
    '/home/deploy/config/starter-template.env',
    '/home/deploy/config/starter-template',
    '/home/deploy/config/.env'
  ].filter(Boolean);

  let envPath = null;
  for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
      envPath = p;
      break;
    }
  }

  if (envPath) {
    const lines = fs.readFileSync(envPath, 'utf8').split('\n');
    for (const line of lines) {
      const match = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)?\s*$/);
      if (match) {
        let val = (match[2] || '').trim();
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
          val = val.slice(1, -1);
        } else {
          val = val.replace(/\s*#.*$/, '').trim();
        }
        loadedEnv[match[1]] = val;
        process.env[match[1]] = val;
      }
    }
  }
} catch {
  // Fall back to default environment
}

module.exports = {
  apps: [
    {
      name: 'sveltekit-starter-template',
      script: 'build/index.js',
      instances: 1,
      exec_mode: 'cluster',
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      env: {
        ...loadedEnv,
        NODE_ENV: loadedEnv.NODE_ENV || 'production',
        PORT: loadedEnv.PORT || process.env.PORT || 3005
      }
    }
  ]
};
