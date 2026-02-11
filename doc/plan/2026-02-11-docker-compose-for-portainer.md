# Plan: Docker Compose for Portainer Deployment

## Context

Kaya Server needs a `docker-compose.yml` for deployment as a Portainer "Stack" on a single VPS. Kamal remains the Rails-native deployment tool; the compose file complements it for Portainer-managed infrastructure. A Caddy reverse proxy handles TLS termination externally (not managed by this compose file). The domain is `savebutton.org`.

Production uses the "free tier" database config: all four Rails databases (primary, cache, queue, cable) share a single `DATABASE_URL`, differing only in migration paths. This is a common Rails 8 setup that avoids the complexity of managing multiple databases on a single Postgres instance.

## Changes

### 1. Fix Dockerfile: Replace SQLite with PostgreSQL client libraries

The existing `Dockerfile` installs `sqlite3` in the base image, but Kaya uses PostgreSQL.

**File:** `Dockerfile`

- Base stage: replace `sqlite3` with `libpq5` in the `apt-get install` line
- Build stage: add `libpq-dev` to the `apt-get install` line

### 2. Update `config/deploy.yml`: Configure Kamal with PostgreSQL accessory

Update the Kamal deploy config to:
- Add a PostgreSQL 17 accessory with an init script that enables `pgcrypto` and `pg_trgm` extensions
- Add `DATABASE_URL` to the clear environment
- Add `POSTGRES_PASSWORD` as a secret
- Configure the proxy for `savebutton.org`

**File:** `config/deploy.yml`

### 3. Update `.kamal/secrets`: Add database secrets

Add `POSTGRES_PASSWORD` to the secrets file.

**File:** `.kamal/secrets`

### 4. Create `docker-compose.yml`

A Portainer-compatible compose file that mirrors the Kamal setup.

**File:** `docker-compose.yml` (new file, project root)

#### Services

**`db` (PostgreSQL 17)**
- Image: `postgres:17`
- Named volume `kaya_pg_data` mounted at `/var/lib/postgresql/data`
- Environment: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB=kaya_production`
- Healthcheck using `pg_isready`
- Init script to enable `pgcrypto` and `pg_trgm` extensions
- Only listens on `127.0.0.1:5432` (not exposed to the internet)

**`web` (Kaya Server)**
- Builds from the local `Dockerfile`
- Depends on `db` (healthy)
- Environment variables:
  - `RAILS_ENV=production`
  - `RAILS_MASTER_KEY` (from `.env` or Portainer stack env)
  - `DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/kaya_production`
  - `SOLID_QUEUE_IN_PUMA=true`
  - `RAILS_LOG_LEVEL=info`
- Named volume `kaya_storage` at `/rails/storage` (ActiveStorage files)
- Exposes port 80 on host `127.0.0.1:3000` (Caddy proxies to `localhost:3000`)

#### Volumes

- `kaya_pg_data` -- PostgreSQL data
- `kaya_storage` -- ActiveStorage (user uploads)

### 5. Create `docker/init-db.sh`

**File:** `docker/init-db.sh` (new file)

A Postgres entrypoint script (mounted into `/docker-entrypoint-initdb.d/`) that enables `pgcrypto` and `pg_trgm` extensions on the `kaya_production` database. Used by both the docker-compose setup and the Kamal accessory.

### 6. Create `.env.example` for Portainer reference

**File:** `.env.example` (new file, project root)

Documents the environment variables that need to be set:

```
RAILS_MASTER_KEY=<from config/master.key>
POSTGRES_USER=kaya
POSTGRES_PASSWORD=<generate a strong password>
```

### 7. Update `.dockerignore`

Add `docker-compose.yml` and `docker/` to `.dockerignore` since they're not needed inside the container image.

## Files Changed

| File | Action |
|------|--------|
| `Dockerfile` | Edit (sqlite3 -> libpq5/libpq-dev) |
| `config/deploy.yml` | Edit (add PG accessory, DATABASE_URL, proxy) |
| `.kamal/secrets` | Edit (add POSTGRES_PASSWORD) |
| `docker-compose.yml` | Create |
| `docker/init-db.sh` | Create |
| `.env.example` | Create |
| `.dockerignore` | Edit (add docker-compose, docker/) |

## Not in Scope

- Caddy configuration (managed externally)
- SSL/TLS termination
- Docker Swarm / multi-node deployment
- CI/CD pipeline
- Backups strategy
- Changes to `config/database.yml` (free tier config is already correct)
