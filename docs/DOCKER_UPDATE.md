# Docker source updates

## First deployment and repeated deployment

```sh
npm run deploy:docker
```

This deploys the source already in the checkout; it does not pull Git. Preserve
your production `.env`. If absent, the script can link a production config from
the existing external paths, or the path specified by `DEPLOY_ENV_FILE`. It never
overwrites `.env`, copies example secrets, forces storage paths or sets mode 777.
Compose resolves the configured data/log mounts and Docker prepares them.

If Compose containers already exist (including stopped containers), deployment
delegates to `update:docker -- --no-pull` and requires a running web container for
its verified backup. A stopped stack is not silently booted against a new schema.

For a first stack, build succeeds before the DB preparation container starts.
An existing database in the data mount is backed up and checked before schema
synchronization. Only an absent file permits new DB initialization; permission
errors and empty/corrupt DBs stop deployment. New DB initialization requires a
non-placeholder AUTH_SECRET of at least 32 characters. Schema setup must succeed
before the web service starts, followed by the shared health checks.

No default admin/demo accounts are created automatically. Provision accounts
explicitly through your intended setup process; do not assume printed default
passwords or run the existing seed script unintentionally.

## Updating a running stack

Run in the server checkout after new commits are available on its remote:

```sh
npm run update:docker
```

For manually uploaded source (including local commits that have not been pushed):

```sh
npm run update:docker -- --no-pull
```

The command requires an existing running web container. It pulls with `--ff-only`,
validates Compose, builds the new image, and streams a snapshot helper into the
running web container. The helper uses SQLite's online backup API, verifies the
snapshot, and stores it under `.deployment-backups` beside the actual configured
DB in the persistent `/app/data` mount. The backup uses the [Node SQLite online
backup API](https://nodejs.org/api/sqlite.html#sqlitebackupsourceDb-path-options).
It does not choose a fallback database or prune logs/backups.

Build/pull/backup failures leave current containers running. After backup succeeds,
the command gracefully stops the web service, verifies that the new mount/config
targets the backed-up DB, and requires Prisma schema synchronization to succeed.
Then it recreates the services.
Web health check must pass for the command to return success.
Inspect the web logs after deployment.
