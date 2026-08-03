# Feature matrix

Legend: **Supported** · **Partial** · **Unsupported** · **API-fallback** (HA REST)

## Product goal

JinjaHA is a **standalone SPM library** that implements as much of Home Assistant’s documented Jinja/template surface as is practical in Swift. Hybrid apps fill `HAStateSnapshot` and use `LocalTemplateRenderer` + `FallbackTemplateRenderer` → `/api/template`.

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
| `{% raw %}` / `{% endraw %}` | Supported | |
| `{% with %}` / `{% endwith %}` | Supported | |
| `{% include %}` / `{% extends %}` / `{% block %}` / `super()` | Supported | |
| `{% import %}` / `{% from ... import %}` | Supported | |
| Callable objects / custom stringify | Supported | |
| Datetime / timedelta values | Supported | `strftime` (incl. Python `%-d` / `%-I` no-pad tokens); date-only `isoformat` |
| `{% do %}` | Supported | Evaluates expression; no output |
| `{% debug %}` | Supported | Dumps defined context keys |
| `{% trans %}` / `{% endtrans %}` | Supported | Optional assignments; gettext `%(name)s` catalog keys via `translationCatalog` / snapshot |

## JinjaHA — helper coverage (catalog-driven)

Source of truth: [HA template functions](https://www.home-assistant.io/template-functions/).

| Category | Status | Notes |
|----------|--------|-------|
| States | Supported | `states`, `is_state`, `is_state_attr`, `state_attr`, `has_value`, `expand` |
| Areas / devices / floors / labels | Supported | Core registry helpers |
| Date & time | Supported | `now`/`utcnow`/`as_*` (incl. `as_datetime` default)/`timedelta`/`strptime`/`timestamp_*`/`today_at`/`relative_time`/`time_since`/`time_until`; `strftime` `%-` tokens |
| Encoding / hash | Supported | `base64_*`, `md5`, `sha1`, `sha256`, `sha512`, `urlencode`, `from_hex`, `pack`/`unpack` (`bBhHiIlLqQfds`, endian, multi-field) |
| Entities / registry | Supported | `entity_name`, `is_hidden_entity`, `integration_entities`, `config_entry_id`, `config_entry_attr` (needs snapshot meta) |
| Repairs | Supported | `issues` / `issue` from `HAStateSnapshot.repairIssues` |
| Translations | Supported | `state_translated` / `state_attr_translated` (+ `{% trans %}`) |
| Math | Supported | `pi`/`e`/`tau`/`log`/`sin`/`cos`/`tan`/`sqrt`/`acos`/`asin`/`atan`/`atan2`/`clamp`/`remap`/`wrap`/`bitwise_*`/`median`/`statistical_mode`/`average` |
| Functional | Supported | `iif`, `apply`, `as_function`, `zip`, `version` (comparable), `ord`, `contains` (+ JinjaCore `namespace`/`cycler`/`joiner`/`lipsum`/`dict`/`range`) |
| Type conversion | Supported | HA `bool`/`add`/`multiply` (+ JinjaCore `int`/`float`/`string`/`bool` tests `odd`/`even`/`divisibleby`) |
| Strings extras | Supported | `ordinal`, `filesizeformat` (JinjaCore), slugify/regex |
| Collections extras | Supported | set ops, `flatten`, `combine`, `shuffle`, `merge_response` (+ JinjaCore `batch`/`slice`/`map`/…) |
| Geo | Supported | `distance` / `closest` (needs home lat/lon) |
| Regex / strings / JSON | Supported | Phase 4 helpers + `to_json`/`from_json` |
| `POST /api/template` | Supported | Hybrid via `FallbackTemplateRenderer` |
| HACS / custom Jinja / arbitrary Python methods | API-fallback | **Permanent** — never emulate a CPython sandbox |

## JinjaHASwiftUI

| Feature | Status | Notes |
|---------|--------|-------|
| `HATemplateText` / `HATemplateMarkdown` last-good-render | Supported | |
| GFM pipe tables in markdown | Supported | `MarkdownDocumentView` |

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
| Upstream process | `Docs/COMPAT.md`, `Compatibility/TRACKED_DIFFERENCES.md` |

## Parity stance

1. **Library completeness:** Implement documented HA template helpers and needed Jinja statements in-process so hybrid apps stay thin.
2. **Permanent API-fallback:** HACS integrations, custom Jinja packages, arbitrary Python object methods, and a full CPython sandbox stay on `FallbackTemplateRenderer` / `POST /api/template` (TD-009).
3. **Validation:** Compatibility goldens + LiveParity + real Lovelace boards (e.g. Work Audit) verify behavior; the HA template-functions catalog drives the backlog.

### Cheat sheet

| Bucket | Meaning | Examples |
|--------|---------|----------|
| **Supported** | Local JinjaHA/JinjaCore | Documented HA helpers in the matrix above |
| **Partial** | Useful subset; deepen when LiveParity/boards fail | Complex `pack` formats, niche datetime edges |
| **API-fallback** | Never in-process | HACS, custom Jinja packages, arbitrary Python/CPython |
