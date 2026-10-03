# API architecture rules

- **Layering (REQ-N-023):** route handlers (`src/modules/*/index.ts` / `*.routes.ts`) only parse input (via `validate`)
  and shape responses. Business rules live in `*.service.ts`. Only services and `src/lib/*` may import Prisma
  (`src/lib/db`) or the file system. Check: `grep -rE "lib/db|from 'fs'|node:fs" src/modules` matches only `*.service.ts`.
- **Errors:** throw `AppError(code)` from `src/lib/errors`; never send raw errors. Express 5 forwards async throws.
- **Validation:** every route uses `validate({body, query, params})` with Zod schemas; unknown keys are stripped.
- **SQL:** Prisma query API or tagged-template `$queryRaw` only (parameterized). Never `$queryRawUnsafe` with input.
- **Logging:** use `src/lib/logger`. Never log request bodies, phone numbers, tokens or passwords. Routes by template.
- **Rate limits:** `rateLimit({windowMs, max, keyGenerator})` from `src/middleware/rateLimit`.
- `src/app.ts` builds the app; `src/server.ts` listens.
