# Geo sources (V2 TASK-02)

All files here are public data. No AMC logo or scraped image is committed. Tests never use the network; they use
`apps/api/test/fixtures/geo/`.

## 1. OpenCity — Amdavad Municipal Corporation Wards Map 2024

| Field | Value |
|---|---|
| Publisher | OpenCity (data.opencity.in), dataset `amdavad-municipal-corporation-wards-map-2024` |
| Dataset page | https://data.opencity.in/dataset/amdavad-municipal-corporation-wards-map-2024 |
| File URL | https://data.opencity.in/dataset/f7505ef4-810a-4119-a649-8e8fb1287e5e/resource/414862b3-b382-4692-963d-38f6ce842483/download/6a6d025b-2b02-4b0e-8bb8-74186eacf071.kml |
| Licence | Other (Public Domain), as listed on the dataset |
| Resource modified | 2025-11-25 (dataset metadata 2025-11-27) → boundary version `opencity-amc-wards-2025-11` |
| Retrieved | 2026-10-04 10:30 IST, one `curl` download |
| Stored as | `raw/amc-wards.kml` (unchanged, 293,763 bytes) |
| SHA-256 | `620f31cbcafb355a7b74b70a9a1fdcf91416dc28377273d41785e700ec8b7bbd` |

Content: 48 placemarks, one per ward, each with `sourcewardname`, `sourcewardcode` (ward number 1–48),
`ward_lgd_code` and `ward_lgd_name` (Local Government Directory). The dataset lists two KML resources with the same
file name; the later one (11:11) was used.

Known differences from AMC's list (handled by `ward-aliases.json`): spellings `Ghatlodia`, `New Wadaj`, `Asarwa`,
`Shahibag`, `Baherampura`, `Dariyapur`, `Saraspur-Rakhiyal` (AMC: Saraspur), `Chandkheda` (AMC: Chandkheda Motera).
Ward 33 is `Sarkhej` in `sourcewardname` but `Vejalpur … Ward No. 33` in the LGD name; AMC's list has Sarkhej.

## 2. AMC CCRS — Zone wise Ward List

| Field | Value |
|---|---|
| Publisher | Amdavad Municipal Corporation, CCRS portal |
| URL | https://amccrs.com/AMCPortal/Home/WardList |
| Retrieved | 2026-10-04 10:35 IST, one `curl` download (HTML 235,286 bytes, SHA-256 `09ec4ac6449b44b19c9450ad0975f8a3774910ea037a4b65db28610181a141c4`) |
| Stored as | `raw/amc-ward-list.txt` — the visible text of the ward directory only (zone, ward name, office address), SHA-256 `7fa68aeeca0fec6467b17964aa4580b87a5c2841519a38567ed88825d668fa57` |
| Licence | Public government information; facts only (names, zones, office addresses) are reused |

Content: 7 zones, 48 wards (Central 6, East 8, North 8, North West 5, South 8, South West 4, West 9), each with a ward
office address. **No per-ward phone numbers are published** (only the city helpline 155303), so `officePhone` is
`null` for every ward. Ward numbers are not on this page; they come from the OpenCity/LGD codes and are checked by
`geo:crosscheck` (KML name → AMC ward → same number).

Known issues: the address shown for Ranip is identical to Chandlodiya's (as published by AMC; kept as-is).
The Gujarati page was not used: ward and zone Gujarati names in `amc-ward-list.json` were compiled by the developer
and need a native reader's review (Open Question 5). `officeAddressGu` is `null` until transcribed.

## Derived files

| File | How |
|---|---|
| `amc-wards.opencity-amc-wards-2025-11.geojson` | `npm run geo:convert` from `raw/amc-wards.kml` |
| `amc-ward-list.json` | Compiled from source 2 (+ ward numbers from source 1, Gujarati names by the developer) |
| `ward-aliases.json` | KML `sourcewardname` → ward number, for names that differ after normalisation |
| `CROSSCHECK.md` | Output of `npm run geo:crosscheck` against the imported dev database |
