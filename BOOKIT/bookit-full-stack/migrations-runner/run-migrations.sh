#!/bin/sh
# Applies every service's migrations, in a fixed order, against the shared
# Postgres instance. Safe to re-run: every migration uses IF NOT EXISTS,
# so running this against an already-migrated database is a no-op.
#
# In a real production setup, each service would run its OWN migrations
# independently (often via a Kubernetes Job as part of the deploy
# pipeline), since each service technically "owns" its own tables even
# when they happen to share a physical database in this dev setup. This
# combined script is a dev-environment convenience.

set -e

echo "Waiting for Postgres to accept connections..."
until pg_isready -h postgres -U "$POSTGRES_USER" > /dev/null 2>&1; do
  sleep 1
done

for f in /migrations/*.sql; do
  echo "Applying $f"
  psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

echo "All migrations applied."
