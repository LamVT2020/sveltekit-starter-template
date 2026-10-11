import { readFileSync, mkdtempSync, mkdirSync, writeFileSync, rmSync, existsSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { afterEach, describe, expect, it, vi } from 'vitest';

const updateSource = readFileSync('scripts/update-docker.sh', 'utf8');
const entrySource = readFileSync('docker-entrypoint.sh', 'utf8');
const backupSource = readFileSync('scripts/docker-db-backup.mjs', 'utf8');
const deploySource = readFileSync('scripts/deploy-docker.sh', 'utf8');
const readySource = readFileSync('scripts/docker-wait-ready.sh', 'utf8');
const fixtures: string[] = [];
afterEach(() => {
  for (const dir of fixtures.splice(0)) rmSync(dir, { recursive: true, force: true });
});

function updateFixture(failure = '', args: string[] = [], options: { deploy?: boolean; existing?: boolean; noEnv?: boolean; externalEnv?: boolean; brokenEnv?: boolean } = {}) {
  const dir = mkdtempSync(path.join(tmpdir(), 'starter-template-docker-mock-'));
  fixtures.push(dir);
  mkdirSync(path.join(dir, 'scripts'));
  mkdirSync(path.join(dir, '.git'));
  mkdirSync(path.join(dir, 'bin'));
  writeFileSync(path.join(dir, 'scripts/update-docker.sh'), updateSource);
  writeFileSync(path.join(dir, 'scripts/docker-db-backup.mjs'), backupSource);
  writeFileSync(path.join(dir, 'scripts/deploy-docker.sh'), deploySource);
  writeFileSync(path.join(dir, 'scripts/docker-wait-ready.sh'), readySource);
  const config = 'DATA_DIR=./fixture-data\nLOG_DIR=./fixture-logs\nPORT=3005\n';
  if (options.brokenEnv) symlinkSync('missing-fixture', path.join(dir, '.env'));
  else if (!options.noEnv && !options.externalEnv) writeFileSync(path.join(dir, '.env'), config);
  const externalFile = path.join(dir, 'external-fixture.env');
  if (options.externalEnv) writeFileSync(externalFile, config);
  const log = path.join(dir, 'commands.log');
  const docker = `#!/bin/bash
echo "docker $*" >> "$MOCK_LOG"
case "$*" in
  'compose version') exit 0 ;;
  'compose config --quiet') [ "$FAILURE" != config ]; exit $? ;;
  'compose build '*) [ "$FAILURE" != build ]; exit $? ;;
  'compose exec '*) [ "$FAILURE" != backup ]; exit $? ;;
  'compose run '*--verify) [ "$FAILURE" != verify ]; exit $? ;;
  'compose run '*--prepare-deploy) [ "$FAILURE" != backup ]; exit $? ;;
  'compose run '*RUN_MIGRATIONS=true*) [ "$FAILURE" != schema ]; exit $? ;;
  'compose ps -q '*) [ "$FAILURE" = missing ] || echo 'mock-container'; exit 0 ;;
  'compose ps -a -q') [ "$EXISTING" = true ] && echo 'existing-container'; exit 0 ;;
  'inspect '*)
    if [ "$FAILURE" = health ]; then echo unhealthy
    else echo healthy; fi ;;
esac
exit 0
`;
  const git = `#!/bin/bash
echo "git $*" >> "$MOCK_LOG"
case "$1" in
  symbolic-ref) echo main ;;
  pull) [ "$FAILURE" != pull ]; exit $? ;;
esac
`;
  for (const [name, content] of Object.entries({ docker, git, sleep: '#!/bin/bash\nexit 0\n' })) writeFileSync(path.join(dir, 'bin', name), content, { mode: 0o755 });
  const result = spawnSync('/bin/bash', [path.join(dir, options.deploy ? 'scripts/deploy-docker.sh' : 'scripts/update-docker.sh'), ...args], {
    env: {
      PATH: `${path.join(dir, 'bin')}:/usr/bin:/bin`,
      MOCK_LOG: log,
      FAILURE: failure,
      EXISTING: String(!!options.existing),
      DEPLOY_ENV_FILE: options.externalEnv ? externalFile : path.join(dir, 'missing-config')
    },
    encoding: 'utf8',
    timeout: 10000
  });
  const commands = existsSync(log) ? readFileSync(log, 'utf8').trim().split('\n') : [];
  return { ...result, commands, config: existsSync(path.join(dir, '.env')) ? readFileSync(path.join(dir, '.env'), 'utf8') : null };
}

describe('SvelteKitStarter Docker deployment failure boundaries', () => {
  it('builds and snapshots before stopping, verifies target DB, migrates without seed, then starts and checks services', () => {
    const r = updateFixture();
    expect(r.status).toBe(0);
    const commandIndex = (needle: string) => r.commands.findIndex((line) => line.includes(needle));
    expect(commandIndex('git pull --ff-only')).toBeLessThan(commandIndex('compose build'));
    expect(commandIndex('compose build')).toBeLessThan(commandIndex('compose exec'));
    expect(commandIndex('compose exec')).toBeLessThan(commandIndex('compose stop -t 60'));
    expect(commandIndex('--verify')).toBeGreaterThan(commandIndex('compose stop'));
    expect(commandIndex('RUN_MIGRATIONS=true')).toBeGreaterThan(commandIndex('--verify'));
    expect(commandIndex('compose up')).toBeGreaterThan(commandIndex('RUN_MIGRATIONS=true'));
    expect(r.commands[commandIndex('RUN_MIGRATIONS=true')]).toContain('SEED_USERS=false');
    expect(r.commands.some((line) => line.includes('rm -f'))).toBe(false);
    expect(r.commands).toContain('docker compose ps -q starter-template');
  });
  it.each(['pull', 'build', 'backup'])('keeps current containers running when %s fails', (failure) => {
    const r = updateFixture(failure);
    expect(r.status).not.toBe(0);
    expect(r.commands.some((line) => /compose (stop|up|run)|rm -f/.test(line))).toBe(false);
  });
  it.each(['verify', 'schema'])('does not start new services after %s fails', (failure) => {
    const r = updateFixture(failure);
    expect(r.status).not.toBe(0);
    expect(r.commands.some((line) => line.includes('compose up'))).toBe(false);
    expect(r.stderr).toContain('maintenance');
  });
  it.each(['health', 'missing'])('returns failure when services are %s', (failure) => {
    const r = updateFixture(failure);
    expect(r.status).not.toBe(0);
    expect(r.stdout).not.toContain('Docker update successful');
  });
  it('supports manually uploaded source without invoking Git', () => {
    const r = updateFixture('', ['--no-pull']);
    expect(r.status).toBe(0);
    expect(r.commands.some((line) => line.startsWith('git '))).toBe(false);
  });
});

describe('SvelteKitStarter Docker first deployment and redeployment', () => {
  it('preserves configuration and builds/prepares DB/schema before starting a fresh stack', () => {
    const r = updateFixture('', [], { deploy: true });
    expect(r.status).toBe(0);
    const index = (needle: string) => r.commands.findIndex((line) => line.includes(needle));
    expect(index('compose build')).toBeLessThan(index('--prepare-deploy'));
    expect(index('--prepare-deploy')).toBeLessThan(index('RUN_MIGRATIONS=true'));
    expect(index('RUN_MIGRATIONS=true')).toBeLessThan(index('compose up'));
    expect(r.commands[index('RUN_MIGRATIONS=true')]).toContain('SEED_USERS=false');
    expect(r.commands.some((line) => /rm -f|compose stop|git pull/.test(line))).toBe(false);
    expect(r.config).toBe('DATA_DIR=./fixture-data\nLOG_DIR=./fixture-logs\nPORT=3005\n');
    expect(r.stdout).toContain('Docker deployment successful');
  });
  it('delegates an existing stack to the verified update flow without pulling or deleting containers', () => {
    const r = updateFixture('', [], { deploy: true, existing: true });
    expect(r.status).toBe(0);
    expect(r.commands.some((line) => line.includes('compose exec'))).toBe(true);
    expect(r.commands.some((line) => line.includes('compose stop -t 60'))).toBe(true);
    expect(r.commands.some((line) => /git pull|rm -f|--prepare-deploy/.test(line))).toBe(false);
  });
  it.each(['config', 'build', 'backup', 'schema', 'health', 'missing'])('fails first deployment on %s instead of claiming success', (failure) => {
    const r = updateFixture(failure, [], { deploy: true });
    expect(r.status).not.toBe(0);
    expect(r.stdout).not.toContain('Docker deployment successful');
    if (!['health', 'missing'].includes(failure)) expect(r.commands.some((line) => line.includes('compose up'))).toBe(false);
  });
  it('keeps an existing deployment running if its backup fails', () => {
    const r = updateFixture('backup', [], { deploy: true, existing: true });
    expect(r.status).not.toBe(0);
    expect(r.commands.some((line) => /compose stop|compose up/.test(line))).toBe(false);
  });
  it('links an explicit production environment without copying defaults', () => {
    const r = updateFixture('', [], { deploy: true, externalEnv: true });
    expect(r.status).toBe(0);
    expect(r.config).toContain('DATA_DIR=./fixture-data');
  });
  it.each([{ noEnv: true }, { brokenEnv: true }])('refuses missing/broken configuration %j before building or writing DB', (option) => {
    const r = updateFixture('', [], { deploy: true, ...option });
    expect(r.status).not.toBe(0);
    expect(r.commands.some((line) => /compose build|compose run|compose up/.test(line))).toBe(false);
  });
});

function backupFixture(
  options: {
    verify?: boolean;
    prepare?: boolean;
    missing?: boolean;
    accessError?: boolean;
    secret?: string;
    failBackup?: boolean;
    corrupt?: boolean;
    wrongInode?: boolean;
    url?: string;
    empty?: boolean;
  } = {}
) {
  const id = '20261009T120000-1-2';
  const source = '/app/data/starter-template.db';
  const target = `/app/data/.deployment-backups/${id}.db`;
  const fs = {
    statSync: vi.fn((name: string) => {
      if (name === source && (options.missing || options.accessError)) throw Object.assign(new Error('fixture unavailable'), { code: options.accessError ? 'EACCES' : 'ENOENT' });
      return { isFile: () => true, size: name === source && options.empty ? 0 : 10, ino: 42 };
    }),
    mkdirSync: vi.fn(),
    closeSync: vi.fn(),
    openSync: vi.fn(() => 1),
    writeFileSync: vi.fn(),
    readFileSync: vi.fn(() => JSON.stringify({ sourcePath: source, sourceInode: options.wrongInode ? 43 : 42, backupId: id }))
  };
  const close = vi.fn();
  const Database = vi.fn(function (this: Record<string, unknown>) {
    this.exec = vi.fn();
    this.close = close;
    this.prepare = vi.fn(() => ({ get: () => ({ count: 1 }), all: () => [{ quick_check: options.corrupt ? 'corrupt' : 'ok' }] }));
  });
  const backup = vi.fn(async () => {
    if (options.failBackup) throw new Error('fixture backup failure');
  });
  const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
  const execute = new AsyncFunction('fs', 'path', 'DatabaseSync', 'backup', 'process', 'console', backupSource.replace(/^import .*;\n/gm, ''));
  const process = {
    env: { DATABASE_URL: options.url ?? 'file:' + source, DEPLOY_BACKUP_ID: id, AUTH_SECRET: options.secret ?? 'fixture-only-auth-secret-32-characters' },
    argv: options.verify ? ['node', 'script', '--verify'] : options.prepare ? ['node', 'script', '--prepare-deploy'] : ['node']
  };
  return { run: () => execute(fs, path, Database, backup, process, { log: vi.fn() }), fs, Database, backup, close, target };
}

describe('SvelteKitStarter deployment snapshot using mocked SQLite and filesystem', () => {
  it('permits schema initialization only for a genuinely missing first-deployment DB', async () => {
    const f = backupFixture({ prepare: true, missing: true });
    await f.run();
    expect(f.Database).not.toHaveBeenCalled();
    expect(f.fs.writeFileSync).not.toHaveBeenCalled();
    const update = backupFixture({ missing: true });
    await expect(update.run()).rejects.toThrow();
    const denied = backupFixture({ prepare: true, accessError: true });
    await expect(denied.run()).rejects.toThrow();
  });
  it('backs up an existing offline DB before first-deployment schema synchronization', async () => {
    const f = backupFixture({ prepare: true });
    await f.run();
    expect(f.backup).toHaveBeenCalledOnce();
    expect(f.fs.writeFileSync).toHaveBeenCalledOnce();
  });
  it.each(['', 'short', 'change-this-to-a-super-secret-at-least-32-chars-long'])('rejects unsafe first-deployment secret without opening a DB', async (secret) => {
    const f = backupFixture({ prepare: true, missing: true, secret });
    await expect(f.run()).rejects.toThrow('non-placeholder');
    expect(f.Database).not.toHaveBeenCalled();
  });
  it('uses exactly the configured production file and writes a manifest only after backup and integrity checks', async () => {
    const f = backupFixture();
    await f.run();
    expect(f.Database.mock.calls).toEqual([
      ['/app/data/starter-template.db', { readOnly: true }],
      [f.target, { readOnly: true }]
    ]);
    expect(f.backup).toHaveBeenCalledOnce();
    expect(f.fs.openSync).toHaveBeenCalledWith(f.target, 'wx', 0o600);
    expect(f.fs.writeFileSync).toHaveBeenCalledOnce();
    expect(f.close).toHaveBeenCalledTimes(2);
  });
  it.each([{ failBackup: true }, { corrupt: true }])('does not certify a failed snapshot: %j', async (options) => {
    const f = backupFixture(options);
    await expect(f.run()).rejects.toThrow();
    expect(f.fs.writeFileSync).not.toHaveBeenCalled();
    expect(f.close).toHaveBeenCalled();
  });
  it.each(['file:./dev.db', 'file:/tmp/wrong.db', 'mysql://fixture'])('refuses fallback/outside-mount URL %s', async (url) => {
    const f = backupFixture({ url });
    await expect(f.run()).rejects.toThrow();
    expect(f.Database).not.toHaveBeenCalled();
  });
  it('refuses an empty source instead of creating a new database', async () => {
    const f = backupFixture({ empty: true });
    await expect(f.run()).rejects.toThrow();
    expect(f.Database).not.toHaveBeenCalled();
  });
  it('verifies the new mount against the snapshot without opening any DB', async () => {
    const f = backupFixture({ verify: true });
    await f.run();
    expect(f.Database).not.toHaveBeenCalled();
    const mismatch = backupFixture({ verify: true, wrongInode: true });
    await expect(mismatch.run()).rejects.toThrow('does not match');
  });
});
