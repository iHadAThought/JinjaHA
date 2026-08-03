# Feature matrix

Legend: **Supported** · **Partial** · **Unsupported** · **API-fallback** (HA REST)

## JinjaCore

| Feature | Status | Notes |
|---------|--------|-------|
| `{{ }}` / `{# #}` / if / for / set / macro | Supported | |
| Filters / tests / expressions | Supported | |
| Env custom globals survive render | Supported | Phase 1 — built-ins then caller overlay |
| Filter/test/global registries | Supported | `registerFilter` / `registerTest` / `registerGlobal` |
| `TemplateLoader` (deny-all default) | Supported | Phase 1 API; `{% include %}` syntax Phase 2 |
| `AttributePolicy` (blocks `_` names) | Supported | Wired into member access + `|attr` |
| `range` override without preprocess | Supported | HA registers capped `range` via merge |
| `{% raw %}` / `{% with %}` / `{% include %}` | Unsupported | Phase 2 |
| `{% extends %}` / `{% block %}` / import | Unsupported | Phase 2 |
| Callable objects | Unsupported | Phase 3 |

## JinjaHA

| Feature | Status | Notes |
|---------|--------|-------|
| `states()` / `is_state` / `state_attr` / `has_value` / `expand` | Supported | |
| Areas / devices / floors / labels | Partial | More helpers planned |
| Datetime helpers | Partial | ISO/numeric shims |
| `POST /api/template` | Supported | |
| Inheritance / raw / with locally | API-fallback | Until Phase 2 |

## JinjaHASwiftUI

| Feature | Status |
|---------|--------|
| `HATemplateText` / `HATemplateMarkdown` last-good-render | Supported |
