// Executed in a container only; never choose a local/fallback database.
import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync, backup } from 'node:sqlite';

async function backupStableSnapshot(sourcePath, targetPath) {
  const source = new DatabaseSync(sourcePath, { readOnly: true });
  try {
    source.exec('PRAGMA busy_timeout = 60000; BEGIN;');
    // Materialize a read snapshot before copying: concurrent WAL commits cannot
    // restart this backup or move its consistency point between batches.
    source.prepare('SELECT count(*) FROM sqlite_schema;').get();
    let lastReported = -1;
    await backup(source, targetPath, {
      rate: 4096,
      progress: ({ remainingPages, totalPages }) => {
        const percent = Math.floor((totalPages - remainingPages) / totalPages * 100 / 10) * 10;
        if (percent !== lastReported) {
          lastReported = percent;
          console.error(`SQLite snapshot: ${percent}%`);
        }
      }
    });
  } finally {
    source.close();
  }
}

const id = process.env.DEPLOY_BACKUP_ID || '';
const url = process.env.DATABASE_URL || '';
if (!/^[0-9]{8}T[0-9]{6}-[0-9]+-[0-9]+$/.test(id)) throw new Error('Invalid deployment backup ID');
if (!url.startsWith('file:/') || url.includes('?') || url.includes('#')) throw new Error('Expected an absolute SQLite DATABASE_URL');
const sourcePath = path.resolve(url.slice(5));
if (!sourcePath.startsWith('/app/data/')) throw new Error('Database must be inside the persistent /app/data mount');
let sourceStat;
try {
  sourceStat = fs.statSync(sourcePath);
} catch (error) {
  if (error.code !== 'ENOENT' || !process.argv.includes('--prepare-deploy')) throw error;
}
if (!sourceStat) {
  // A first deployment must not initialize from placeholder authentication secrets.
  const secret = (process.env.AUTH_SECRET || process.env.JWT_SECRET || process.env.SESSION_SECRET || '').trim();
  if (secret.length < 32 || /change_in_production|change-in-production|your_super_secret|super-secret|changeme|change-this/i.test(secret)) {
    throw new Error('Configure a non-placeholder AUTH_SECRET before first deployment');
  }
  console.log('No existing database in the configured data mount; schema initialization may proceed.');
} else {
  if (!sourceStat.isFile() || sourceStat.size === 0) throw new Error('Production database is missing or empty');
  const directory = path.join(path.dirname(sourcePath), '.deployment-backups');
  const targetPath = path.join(directory, `${id}.db`);
  const manifestPath = path.join(directory, `${id}.json`);

  if (process.argv.includes('--verify')) {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    if (manifest.sourcePath !== sourcePath || manifest.sourceInode !== sourceStat.ino || manifest.backupId !== id || fs.statSync(targetPath).size <= 0) {
      throw new Error('New deployment config does not match the verified database snapshot');
    }
    console.log('Verified deployment targets the backed-up database.');
  } else {
    fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
    // Reserve a unique name; never overwrite another snapshot.
    fs.closeSync(fs.openSync(targetPath, 'wx', 0o600));
    await backupStableSnapshot(sourcePath, targetPath);
    const snapshot = new DatabaseSync(targetPath, { readOnly: true });
    try {
      const checks = snapshot.prepare('PRAGMA quick_check;').all();
      if (checks.length !== 1 || Object.values(checks[0])[0] !== 'ok') throw new Error('Snapshot integrity check failed');
    } finally {
      snapshot.close();
    }
    if (fs.statSync(targetPath).size <= 0) throw new Error('Snapshot is empty');
    fs.writeFileSync(manifestPath, JSON.stringify({ backupId: id, sourcePath, sourceInode: sourceStat.ino }), { flag: 'wx', mode: 0o600 });
    console.log(`Verified deployment snapshot: ${targetPath}`);
  }
}
