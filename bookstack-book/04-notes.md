# Notes

Working notes for the JinjaHA project.

## 2026-08-02

- Created Forgejo repo `Brendan/JinjaHA` and pushed `master`.
- Phase 0–6 complete: engine, helpers, test corpus, CompareDemo + screenshots.
- Safe `range` is registered via env override (no preprocess).
- Next: Phase 7 upstream COMPAT process polish.

## Security reminders

- Default `TemplateLoader` denies all includes.
- Do not log bearer tokens; API renderer scrubs tokens from errors.
- Prefer `DefaultAttributePolicy` for untrusted templates.
