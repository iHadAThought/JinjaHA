# Notes

Working notes for the JinjaHA project.

## 2026-08-02

- Created Forgejo repo `Brendan/JinjaHA` and pushed `master`.
- Phase 0–3 complete: owned `JinjaCore`, statements, callable `states` + entity stringify (no preprocess).
- Safe `range` is registered via env override (no preprocess).
- Next: Phase 4 HA helpers (`iif`, `is_number`, regex, …).

## Security reminders

- Default `TemplateLoader` denies all includes.
- Do not log bearer tokens; API renderer scrubs tokens from errors.
- Prefer `DefaultAttributePolicy` for untrusted templates.
