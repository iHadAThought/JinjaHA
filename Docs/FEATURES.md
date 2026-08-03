# Feature matrix

Legend: **Supported** · **Partial** · **Unsupported** · **API-fallback** (HA REST)

## JinjaCore

| Feature | Status | Notes |
|---------|--------|-------|
| `{{ }}` / `{# #}` / if / for / set / macro | Supported | |
| Filters / tests / expressions | Supported | |
| Env custom globals survive render | Supported | Phase 1 — built-ins then caller overlay |
| Filter/test/global registries | Supported | `registerFilter` / `registerTest` / `registerGlobal` |
| `TemplateLoader` (deny-all default) | Supported | Deny-all by default; `DictionaryTemplateLoader` for allowlists |
| `AttributePolicy` (blocks `_` names) | Supported | Wired into member access + `|attr` |
| `range` override without preprocess | Supported | HA registers capped `range` via merge |
| `{% raw %}` / `{% endraw %}` | Supported | Phase 2 — lexer collapses to literal text |
| `{% with %}` / `{% endwith %}` | Supported | Phase 2 — scoped assignments |
| `{% include %}` | Supported | Phase 2 — `ignore missing`, `with`/`without context` |
| `{% extends %}` / `{% block %}` / `super()` | Supported | Phase 2 — child overrides via loader |
| `{% import %}` / `{% from ... import %}` | Supported | Phase 2 — macros into namespace or aliases |
| Callable objects | Supported | Phase 3 — `Value.object(..., call:)` |
| Custom object stringify | Supported | Phase 3 — `stringRepresentation` |
| Datetime / timedelta values | Supported | `Value.datetime` / `Value.timedelta`; `+`/`-` arithmetic; `strftime`; date-only `isoformat` |
| `{% do %}` | Unsupported | Optional backlog — **gated on real-board failure**, not feature completeness |
| `{% debug %}` | Unsupported | Optional backlog — gated on real-board failure |
| Line statements / `{% trans %}` i18n | Unsupported | Optional backlog — gated on real-board failure |

## JinjaHA

| Feature | Status | Notes |
|---------|--------|-------|
| `states()` / `is_state` / `state_attr` / `has_value` / `expand` | Supported | Callable object — no preprocess |
| `\| states` filter | Supported | Same function as `states(...)` |
| `states.domain.object` + print → state | Supported | Entity `stringRepresentation` |
| `iif` / `is_number` / `is_defined` | Supported | Phase 4 — function, filter, and tests |
| `slugify` / `average` | Supported | Phase 4 |
| `regex_match` / `search` / `replace` / `findall` | Supported | Phase 4 (+ `match`/`search` tests) |
| `floor_entities` | Supported | Phase 4 |
| `labels()` overload | Supported | All labels, or labels for entity/device/area |
| Areas / devices / floors / labels | Supported | Core registry helpers present |
| Datetime objects | Supported | `now`/`utcnow`/`as_datetime`/`today_at`/`strptime` return datetime; `\| as_datetime` filter; `strftime`; `last_changed`/`last_updated` too |
| Timedelta + `total_seconds()` | Supported | `timedelta(...)` / `as_timedelta`; datetime−datetime → timedelta |
| `relative_time` / `time_since` / `time_until` | Supported | Humanized strings |
| Math extras (`pi`/`e`/`log`/`sin`/`cos`/`tan`/`sqrt`) | Supported | |
| Geo (`distance` / `closest`) | Supported | Needs `HAStateSnapshot.latitude`/`longitude` (+ entity lat/lon attrs) |
| Encoding / hash (`base64_*` / `md5` / `sha256` / `urlencode`) | Supported | |
| `POST /api/template` | Supported | **Permanent API-fallback** via `FallbackTemplateRenderer` for HACS / arbitrary Python / full CPython sandbox |
| Inheritance / raw / with / include / import | Supported | Phase 2 in JinjaCore (loader still required for include/extends) |
| Translations / repairs helpers | Unsupported | Optional backlog — gated on real-board failure; otherwise API-fallback |
| HACS / custom Jinja / arbitrary Python methods | API-fallback | **Permanent** — do not chase a CPython sandbox; keep hybrid Local → `/api/template` |
| Speculative helpers (`is_hidden_entity`, `pack`/`unpack`, …) | Unsupported | Optional backlog — **only if a real-board golden fails without them** |

## JinjaHASwiftUI

| Feature | Status | Notes |
|---------|--------|-------|
| `HATemplateText` / `HATemplateMarkdown` last-good-render | Supported | |
| GFM pipe tables in markdown | Supported | `MarkdownDocumentView` (Foundation markdown collapses tables) |

## Version identity

| Constant | Location |
|----------|----------|
| `JinjaCoreInfo.dialectVersion` | `Sources/JinjaCore/DialectVersion.swift` |
| `JinjaCoreInfo.implementationRevision` | same |
| `JinjaHAInfo.homeAssistantHelpersRevision` | `Sources/JinjaHA/JinjaHAInfo.swift` |

## Test corpus

| Area | Location |
|------|----------|
| Test corpus | `Compatibility/`, `Fixtures/`, `Tests/*` |
| Work Audit board goldens | `Compatibility/home-assistant/work_audit_*.jinja` + `Fixtures/snapshots/work_audit.json` |
| Live local↔API parity | `LiveParityTests` (`HA_URL` + `HA_TOKEN`) |
| CompareDemo | `Examples/CompareDemo` + `Docs/screenshots/` |
| Upstream process | `Docs/COMPAT.md`, `Compatibility/TRACKED_DIFFERENCES.md`, `Scripts/check-compat-notes.sh` |

## Parity stance

1. **Permanent API-fallback:** HACS integrations, arbitrary Python object methods, and a full CPython sandbox stay on `FallbackTemplateRenderer` / `POST /api/template`. Do not chase feature-complete Python emulation.
2. **Board-driven hardening:** Add Compatibility goldens from real Lovelace boards; expand LiveParity; implement only gaps those goldens expose.
3. **Optional backlog** (`{% do %}`, translations, repairs, `is_hidden_entity`, `pack`/`unpack`, …): gated on a failing real-board golden, not checklist completeness.
