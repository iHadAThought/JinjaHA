# Roadmap & phases

## Build phases (engine ownership) — all done

| Phase | Status | Content |
|-------|--------|---------|
| 0 Own engine | Done | Vendor JinjaCore, drop HF dep |
| 1 Foundation | Done | Env merge, registries, loader, AttributePolicy |
| 2 Statements | Done | `raw`, `with`, `include`, `extends`/`block`/`super()`, `import`/`from` |
| 3 Value model | Done | Callable `states`, entity stringify, no preprocess |
| 4 HA helpers | Done | `iif`, `is_number`, `slugify`, `average`, regex, `floor_entities`, labels overload |
| 5 Tests corpus | Done | JinjaCore/HA/SwiftUI breadth + Compatibility/ goldens |
| 6 CompareDemo | Done | Side-by-side demo + `Docs/screenshots/` |
| 7 Upstream process | Done | COMPAT cadence, tracked differences, `check-compat-notes.sh` |

## Catalog completeness (library hybrid-ready) — done through v0.3.0

| Phase | Tag | Status |
|-------|-----|--------|
| Wave 0–2 + docs stance | v0.2.0 | Done — statements, encoding/registry/repairs, math/functional/collections |
| Phase 1 leftovers | v0.2.1 | Done — `tau`/`remap`/`wrap`/`bool`/`add`/`multiply`/`ordinal`/`as_function`/… |
| Phase 2 depth | v0.2.2 | Done — pack/unpack, version compare, trans placeholders, `as_datetime` default |
| Phase 3–4 snapshot DX + validation | v0.3.0 | Done — merge/registry decode, LiveParity strip, cookbook, MinimalRender hybrid example |
| Phase 5 app consumer | — | **Deferred** — separate repo/chat; do not wire apps from library-only work |

## Ongoing

- Grow Compatibility goldens + LiveParity (`HA_URL` + `HA_TOKEN`) as upstream HA/Jinja change
- Re-check Pallets/HA docs ≤ every 90 days

See [`Docs/FEATURES.md`](../FEATURES.md) and [`Docs/COMPAT.md`](../COMPAT.md).
