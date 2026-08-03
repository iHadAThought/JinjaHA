# Tracked intentional differences

Seed notes for cases where JinjaHA / JinjaCore deliberately diverge from CPython Jinja2 or HA’s Python runtime. Prefer a short Compatibility golden when a difference is easy to fixture.

| ID | Topic | Layer | Status | Note |
|----|-------|-------|--------|------|
| TD-001 | Callable objects + stringify | JinjaCore | Intentional | `Value.object(call:stringRepresentation:)` — no Python `__call__` / `__str__` |
| TD-002 | Implicit string concat | JinjaCore | Intentional | Adjacent **string literals** only; identifiers are not concatenated (protects `as` / `ignore missing`) |
| TD-003 | Template loading | JinjaCore | Intentional | Default `DenyAllTemplateLoader`; apps must install an allowlist |
| TD-004 | Attribute sandbox | JinjaCore | Intentional | `DefaultAttributePolicy` blocks `_`-prefixed names (incl. `|attr`) |
| TD-005 | HA `states` dual-use | JinjaHA | Intentional | One callable object: `states()`, `states.x.y`, `\| states` — no preprocess |
| TD-006 | Regex escapes in goldens | Tests | Intentional | Lexer consumes `\\`; prefer `[0-9]` or carefully doubled escapes in Swift strings |
| TD-007 | GFM tables in SwiftUI | JinjaHASwiftUI | Intentional | `MarkdownDocumentView` renders pipe tables; Foundation markdown collapses them |

## Adding a new tracked difference

1. Add a row here with a stable `TD-NNN` id.
2. If testable, add `Compatibility/…` goldens that document expected JinjaHA behavior.
3. Mention the ID in the PR/commit when behavior changes.
