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
| Callable objects | Unsupported | Phase 3 |

## JinjaHA

| Feature | Status | Notes |
|---------|--------|-------|
| `states()` / `is_state` / `state_attr` / `has_value` / `expand` | Supported | |
| Areas / devices / floors / labels | Partial | More helpers planned |
| Datetime helpers | Partial | ISO/numeric shims |
| `POST /api/template` | Supported | |
| Inheritance / raw / with / include / import | Supported | Phase 2 in JinjaCore (loader still required for include/extends) |

## JinjaHASwiftUI

| Feature | Status |
|---------|--------|
| `HATemplateText` / `HATemplateMarkdown` last-good-render | Supported |
