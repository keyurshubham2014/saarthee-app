# Saarthee — Ahmedabad civic accountability pilot

- **v2 specification (current):** [docs/v2/saarthee-v2-spec.md](docs/v2/saarthee-v2-spec.md) · v2 plan: [docs/tasks-v2/00-task-summary.md](docs/tasks-v2/00-task-summary.md) · v2 demo: [docs/demo/DEMO-v2.md](docs/demo/DEMO-v2.md) · pilot launch: [docs/v2/pilot-launch-checklist.md](docs/v2/pilot-launch-checklist.md)
- v1 spec index (superseded by v2 where they differ): [docs/00-master-index.md](docs/00-master-index.md)
- v1 task plan: [docs/tasks/00-task-summary.md](docs/tasks/00-task-summary.md)
- v1 demo script: [docs/demo/DEMO.md](docs/demo/DEMO.md) (`npm run demo:reset` now restores the v2 demo)
- Operations (v2): [environments](docs/ops/environments.md) · [deploy](docs/ops/deploy.md) ·
  [backup & restore](docs/ops/backup-restore.md) · [restore drills](docs/ops/restore-drill.md) ·
  [monitoring](docs/ops/monitoring.md) · [Android release](docs/ops/release-android.md)

Layout: `apps/api` (Express + TypeScript + Prisma), `apps/mobile` (Flutter), `infra` (Docker Compose for PostgreSQL), `docs`.

## Quick start (v2 API)

```bash
docker compose -f infra/docker-compose.yml --env-file infra/.env up -d db   # PostGIS (native arm64 build: infra/postgis/Dockerfile)
npm run db:upgrade-postgis      # only once, if you still have a v1 (plain postgres) volume: dump, switch, verify counts
cd apps/api && npm ci && npx prisma migrate deploy && npx prisma db seed && cd ../..
npm run legacy:migrate          # copy v1 complaints into v2 issues (idempotent)
npm run api:test                # Vitest + Supertest; setup in apps/api/test/README.md
```
