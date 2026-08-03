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
| Datetime helpers | Partial | ISO/numeric shims |
| `POST /api/template` | Supported | |
| Inheritance / raw / with / include / import | Supported | Phase 2 in JinjaCore (loader still required for include/extends) |

## JinjaHASwiftUI

| Feature | Status |
|---------|--------|
| `HATemplateText` / `HATemplateMarkdown` last-good-render | Supported |

## Test corpus

| Area | Location |
|------|----------|
| Dialect goldens | `Compatibility/jinja-3.1/` |
| HA helper goldens | `Compatibility/home-assistant/` + `Fixtures/templates/` |
| Unit suites | `Tests/JinjaCoreTests`, `JinjaHATests`, `JinjaHASwiftUITests` |
