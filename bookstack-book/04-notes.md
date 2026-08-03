# Notes

Working notes for the JinjaHA project.

## 2026-08-02

- Created Forgejo repo `Brendan/JinjaHA` and pushed `master`.
- Phase 0+1 complete: owned `JinjaCore`, env merge fix, registries, deny-all loader, attribute policy.
- `states()` still uses preprocess (`__states__`) until Phase 3 callable objects.
- Safe `range` is registered via env override (no preprocess).
- Tests: 37 passing (1 live-parity skipped without `HA_URL`/`HA_TOKEN`).

## Security reminders

- Default `TemplateLoader` denies all includes.
- Do not log bearer tokens; API renderer scrubs tokens from errors.
- Prefer `DefaultAttributePolicy` for untrusted templates.
