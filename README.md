# Saarthee — Ahmedabad civic accountability pilot

- Spec index: [docs/00-master-index.md](docs/00-master-index.md)
- Task plan and progress: [docs/tasks/00-task-summary.md](docs/tasks/00-task-summary.md)
- Demo script: [docs/demo/DEMO.md](docs/demo/DEMO.md)

Layout: `apps/api` (Express + TypeScript + Prisma), `apps/mobile` (Flutter), `infra` (Docker Compose for PostgreSQL), `docs`.

## Quick start (v2 API)

```bash
docker compose -f infra/docker-compose.yml --env-file infra/.env up -d db   # PostGIS (native arm64 build: infra/postgis/Dockerfile)
npm run db:upgrade-postgis      # only once, if you still have a v1 (plain postgres) volume: dump, switch, verify counts
cd apps/api && npm ci && npx prisma migrate deploy && npx prisma db seed && cd ../..
npm run legacy:migrate          # copy v1 complaints into v2 issues (idempotent)
npm run api:test                # Vitest + Supertest; setup in apps/api/test/README.md
```
