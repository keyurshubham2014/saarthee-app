# Representative roster — sources (TASK-09)

**Status: Deferred — roster compilation.** The real 2026–31 roster for the five pilot wards (6 Nava Vadaj,
9 Naranpura, 18 Navrangpura, 30 Paldi, 31 Vasna — 20 corporators), all MLAs/MPs over AMC wards and the full
ward ↔ assembly-constituency mapping must be compiled by hand from the primary sources below, spot-checked
by a second person (M-09-07: 10 rows against their source URLs) and imported **on staging only**:

```bash
npm run constituencies:import -- --file data/representatives/constituencies.csv --dry-run
npm run constituencies:import -- --file data/representatives/constituencies.csv
npm run reps:import -- --file data/representatives/roster-2026.csv --dry-run
npm run reps:import -- --file data/representatives/roster-2026.csv
```

Until then the dev seed uses fictional **"Sample"** representatives (prisma/seed/modules/070-representatives.ts).
`roster-2026.csv` and `constituencies.csv` in this folder are header-only templates.

## Rules (enforced by the importer, the staff API and a DB CHECK)

- Every row has an `https://` `source_url` (the primary source) and a `last_verified_at` date not in the future.
- Only official information: names as printed, party exactly as printed in the result (plain text), term dates,
  an official **079 office landline** and an official email. **No mobile numbers** — the importer rejects any
  10-digit number starting 6–9 ("Mobile numbers are never imported…"). No photos (initials avatars only).
- A ward has at most 4 active corporators. MLAs map to one AC; MPs list every AC of their Lok Sabha seat (`44;45;46`).

## Primary sources

| Data | Source | Notes |
|---|---|---|
| Corporators (AMC 2026) | State Election Commission, Gujarat — AMC general election 2026 results | primary `source_url` per row |
| Cross-check | MyNeta (ADR) candidate affidavits | names/party spelling only |
| MLAs | Election Commission of India — Gujarat Assembly 2022 results | |
| MPs | Election Commission of India — Lok Sabha 2024 results | |
| Ward ↔ AC mapping | Delimitation of Parliamentary and Assembly Constituencies Order, 2008; AMC ward list | cross-check with TASK-02 boundaries |
| Office contacts | AMC ward/zone office pages; official representative pages | landlines and official emails only |
