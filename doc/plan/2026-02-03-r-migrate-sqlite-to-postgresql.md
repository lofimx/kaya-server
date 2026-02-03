# Refactoring: Migrate from SQLite to PostgreSQL

## Summary

Replace SQLite with PostgreSQL 17 as the database for all Rails environments. Convert all hand-rolled UUID primary keys (`string(36)` + `SecureRandom.uuid` callbacks) to native PostgreSQL `uuid` type via `pgcrypto`'s `gen_random_uuid()`.

## Motivation

SQLite lacks native UUID support, which caused the PaperTrail `versions` table to fail with `NOT NULL constraint failed: versions.id`. Every UUID table in the project requires either SQLite-specific `randomblob()` hacks (ActiveStorage) or application-level `before_create` callbacks (all domain models). PostgreSQL solves this natively with `pgcrypto` and provides `pg_trgm` for future full-text/trigram search needs (ref: ADR 0005).

## Prerequisites (manual, by developer)

1. PostgreSQL 17 installed (Debian Trixie package)
2. PostgreSQL service running: `sudo systemctl enable --now postgresql`
3. OS-matching PostgreSQL user with createdb: `sudo -u postgres createuser --createdb steven`
4. Verify: `psql -d postgres -c "SELECT version();"`

## Plan

### 1. Switch gem from `sqlite3` to `pg`

**File:** `Gemfile`

- Remove `gem "sqlite3", ">= 2.1"`
- Add `gem "pg", "~> 1.5"`
- Run `bundle install`

### 2. Rewrite `config/database.yml` for PostgreSQL

**File:** `config/database.yml`

- `default` adapter: `postgresql`, `encoding: unicode`
- `development.primary`: database `kaya_development`
- `development.queue`: database `kaya_development_queue`, same migrations_paths
- `test`: database `kaya_test`
- `production.primary`: database `kaya_production` (with `ENV["DATABASE_URL"]` support)
- `production.cache`: database `kaya_production_cache`
- `production.queue`: database `kaya_production_queue`
- `production.cable`: database `kaya_production_cable`

### 3. Enable `pgcrypto` extension

**File:** new migration or added to first migration

Add `enable_extension "pgcrypto"` to the `CreateUsers` migration (the first migration), since all subsequent migrations depend on UUID generation. This keeps the migration history self-contained.

### 4. Rewrite migrations for native UUID primary keys

Convert all `string(36)` primary keys to `id: :uuid`. Convert all `string :fk_id, limit: 36` foreign keys to `uuid :fk_id`.

**Files and changes:**

| Migration | Table | PK change | FK changes |
|---|---|---|---|
| `20260107040029_create_users.rb` | `users` | `id: false` + `t.string :id, limit: 36, ...` => `id: :uuid` | -- |
| `20260107040030_create_sessions.rb` | `sessions` | (integer PK) => `id: :uuid` | `t.string :user_id, limit: 36` => `t.uuid :user_id` |
| `20260107040122_create_identities.rb` | `identities` | (integer PK) => `id: :uuid` | `t.string :user_id, limit: 36` => `t.uuid :user_id` |
| `*_create_active_storage_tables` | `active_storage_*` | Delete old migration, regenerate via `bin/rails active_storage:install`, then edit to use `id: :uuid` and `t.uuid` for FKs | -- |
| `20260127005245_create_angas.rb` | `angas` | `id: false` + `t.string :id, limit: 36, ...` => `id: :uuid` | `t.string :user_id, limit: 36` => `t.uuid :user_id` |
| `20260128213533_create_bookmarks.rb` | `bookmarks` | `id: { type: :string, limit: 36 }` => `id: :uuid` | `t.string :anga_id, limit: 36` => `t.uuid :anga_id` |
| `20260130213445_create_metas.rb` | `metas` | `id: false` + `t.string :id, limit: 36, ...` => `id: :uuid` | `t.string :user_id, limit: 36` => `t.uuid :user_id`; `t.string :anga_id, limit: 36` => `t.uuid :anga_id` |
| `20260203050229_create_texts.rb` | `texts` | `id: { type: :string, limit: 36 }` => `id: :uuid` | `t.string :anga_id, limit: 36` => `t.uuid :anga_id` |
| `20260203202747_create_versions.rb` | `versions` | `id: { type: :string, limit: 36, default: -> { randomblob... } }` => `id: :uuid` | `t.string :item_id` stays as `t.string :item_id` (PaperTrail stores polymorphic IDs as strings) |

### 5. Remove `generate_uuid` callbacks from models

**Files (5 models):**

- `app/models/user.rb` -- remove `before_create :generate_uuid` and the private `generate_uuid` method
- `app/models/anga.rb` -- remove `before_create :generate_uuid` and the private `generate_uuid` method
- `app/models/bookmark.rb` -- remove `before_create :generate_uuid` and the private `generate_uuid` method
- `app/models/meta.rb` -- remove `before_create :generate_uuid` and the private `generate_uuid` method
- `app/models/text.rb` -- remove `before_create :generate_uuid` and the private `generate_uuid` method

PostgreSQL + `pgcrypto` will generate UUIDs at the database level via `gen_random_uuid()`.

### 6. Update Solid Queue config for PostgreSQL

**File:** `config/environments/development.rb`

The `solid_queue.connects_to` setting already points to `{ database: { writing: :queue } }`, which will resolve to the new `kaya_development_queue` PostgreSQL database. No code change needed, but the queue database must be created and its migrations run.

**File:** `config/environments/production.rb`

Same -- already configured correctly.

### 7. Verify

- `bin/rails db:create`
- `bin/rails db:migrate`
- `rake test`
- Manual test: create a user, connect a Google OAuth identity, create a bookmark

## Files Changed

- `Gemfile`
- `Gemfile.lock` (via `bundle install`)
- `config/database.yml`
- `db/migrate/20260107040029_create_users.rb`
- `db/migrate/20260107040030_create_sessions.rb`
- `db/migrate/20260107040122_create_identities.rb`
- `db/migrate/20260126223158_create_active_storage_tables.active_storage.rb` (deleted, regenerated)
- `db/migrate/20260127005245_create_angas.rb`
- `db/migrate/20260128213533_create_bookmarks.rb`
- `db/migrate/20260130213445_create_metas.rb`
- `db/migrate/20260203050229_create_texts.rb`
- `db/migrate/20260203202747_create_versions.rb`
- `app/models/user.rb`
- `app/models/anga.rb`
- `app/models/bookmark.rb`
- `app/models/meta.rb`
- `app/models/text.rb`

## Risks

- **Data loss:** The SQLite development database will be abandoned. This is acceptable since this is a development environment. Production migration (if SQLite data existed) would require a separate data migration plan, but no production SQLite database exists.
- **ActiveStorage migration:** This is a generated migration (`active_storage`). Editing it is safe since it has already been applied to SQLite and will be applied fresh to PostgreSQL.
- **Solid Queue/Cache/Cable:** These use their own databases. The `queue` database was previously a separate SQLite file; it becomes a separate PostgreSQL database. Cache and cable databases only exist in the production config.
