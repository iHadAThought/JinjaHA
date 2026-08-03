# Architecture

```
Apps → JinjaHASwiftUI → JinjaHA → JinjaCore
                 ↘ REST /api/template (optional)
```

## Layers

| Layer | Owns | Change when… |
|-------|------|----------------|
| JinjaCore | Lexer, parser, AST, interpreter, built-in filters/tests, statements | Pallets Jinja syntax changes |
| JinjaHA | `HAStateSnapshot`, HA globals/filters, API client, limits | HA adds template functions |
| JinjaHASwiftUI | Views + `TemplateRenderModel` | UI / markdown presentation |

## Extension points

- `registerFilter` / `registerTest` / `registerGlobal`
- `TemplateLoader` (default **deny-all**; required for include/extends/import)
- `AttributePolicy` (default blocks `_`-prefixed names)
- `TemplateRendering` — local / API / fallback backends

## Statements (Phase 2)

JinjaCore supports `{% raw %}`, `{% with %}`, `{% include %}` (`ignore missing`, `with`/`without context`), `{% extends %}` / `{% block %}` / `{{ super() }}`, and `{% import %}` / `{% from ... import %}`.

## Value model (Phase 3)

`Value.object` may include an optional `call` hook and `stringRepresentation`. HA `states` is a callable object (dotted access + `states(...)` + `| states`); entity objects print their state string.

## HA helpers (Phase 4)

Registered via Environment registries: `iif`, `is_number`, `is_defined`, `slugify`, `average`, regex helpers, `floor_entities`, and `labels(lookup?)` overload.

## Test corpus (Phase 5)

- `Tests/JinjaCoreTests` — filters, control flow, sandbox, Compatibility/jinja-3.1
- `Tests/JinjaHATests` — goldens under Fixtures/templates + Compatibility/home-assistant
- `Tests/JinjaHASwiftUITests` — last-good, cancel, re-render


## Environment merge

Root environments seed built-ins **first**, then caller overlays. Custom `range` and HA globals survive `Interpreter.interpret` via `Environment(copying:)`.
