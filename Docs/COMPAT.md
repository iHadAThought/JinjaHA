# Compatibility

## Dialect target

| Field | Value |
|-------|--------|
| Jinja dialect | 3.1.x (Pallets) |
| `JinjaCoreInfo.dialectVersion` | 3.1 |
| Vendored baseline | huggingface/swift-jinja 2.4.2 (owned thereafter) |
| Last reviewed | 2026-08-02 |

## Intentional differences from CPython Jinja2

- No Python object model / arbitrary method calls on host objects.
- Sandbox is `AttributePolicy` (default denies `_` prefixed names), not a full Python sandbox.
- HA helpers live in **JinjaHA**, not JinjaCore.

## How to absorb a future Jinja release

1. Read [Pallets Jinja changes](https://jinja.palletsprojects.com/en/stable/changes/).
2. Add failing fixtures under `Compatibility/jinja-<version>/`.
3. Implement in **JinjaCore** only (syntax/runtime) or **JinjaHA** (HA helpers).
4. Bump `JinjaCoreInfo.implementationRevision` / `dialectVersion` as appropriate.
5. Update [`FEATURES.md`](FEATURES.md) and this file’s “Last reviewed” date.

## Home Assistant helpers

Track [HA templating](https://www.home-assistant.io/docs/templating/) and [template functions](https://www.home-assistant.io/template-functions/). New helpers register via Environment registries in JinjaHA — never via lexer changes.
