# Compatibility corpus

| Folder | Purpose |
|--------|---------|
| `jinja-3.1/` | Upstream-shaped Jinja dialect cases (JinjaCore only) |
| `home-assistant/` | HA helper parity against a fixed snapshot |

## Process

1. Read [Pallets Jinja changes](https://jinja.palletsprojects.com/en/stable/changes/) or [HA template functions](https://www.home-assistant.io/template-functions/).
2. Add a **failing** `.jinja` + `.expected.txt` under the matching folder.
3. Implement in JinjaCore (syntax) or JinjaHA (helpers).
4. Update `Docs/FEATURES.md` and `Docs/COMPAT.md` “Last reviewed”.

## Tracked intentional differences

| Topic | Note |
|-------|------|
| Object call / stringify | Swift `Value.object(call:stringRepresentation:)` — not Python objects |
| Implicit string concat | Adjacent **string literals** only (not identifiers) |
| Template loading | Deny-all `TemplateLoader` by default |
| Regex escapes in tests | Lexer treats `\\` escapes; prefer `[0-9]` or double-escaped `\\\\d` in Swift test strings |
