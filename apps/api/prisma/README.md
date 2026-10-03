# Database: migrate, seed, reset, backup

- `npm run db:migrate` — apply migrations (`prisma migrate dev`). Applied migrations are **never edited**; corrections go in a new migration (04 §7.2).
- `npm run db:seed` — reference data (idempotent) + dev sample set. Refuses unless `APP_ENV=development` and no non-seed complaints exist. Remove `SEED_ADMIN_PASSWORD` from `.env` after seeding outside the demo machine.
- `npm run db:reset` — refuses unless `APP_ENV=development`, asks you to type `RESET`, then drops the volume, recreates, migrates and seeds.
- Hand-written SQL (CHECKs, partial indexes, events identity, views) is in the migration files, each block commented with why.

## Backups before risky migrations (05 §8, 04 §9.1)

Write dumps **outside the project**; never commit them (`*.dump` is git-ignored):

```bash
mkdir -p ~/saarthee-backups
docker compose -f infra/docker-compose.yml --env-file infra/.env exec -T db \
  pg_dump -U saarthee -d saarthee -Fc > ~/saarthee-backups/saarthee-$(date +%Y%m%d-%H%M).dump
```

Restore: `docker compose ... exec -T db pg_restore -U saarthee -d saarthee --clean < <file>.dump`.
