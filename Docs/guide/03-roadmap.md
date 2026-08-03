# Roadmap & phases

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

All planned build phases complete. Ongoing work: grow Compatibility goldens as upstream releases land.

See also [`Docs/FEATURES.md`](../FEATURES.md) and [`Docs/COMPAT.md`](../COMPAT.md).
