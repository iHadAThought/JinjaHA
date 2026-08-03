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

## Extension points (Phase 1)

- `registerFilter` / `registerTest` / `registerGlobal`
- `TemplateLoader` (default **deny-all**)
- `AttributePolicy` (default blocks `_`-prefixed names)
- `TemplateRendering` — local / API / fallback backends

## Environment merge

Root environments seed built-ins **first**, then caller overlays. Custom `range` and HA globals survive `Interpreter.interpret` via `Environment(copying:)`.
