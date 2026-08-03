# Notes

Working notes for the JinjaHA project.

## 2026-08-02

- Created Forgejo repo `Brendan/JinjaHA` and pushed `master`.
- Phase 0–5 complete: engine, helpers, and Compatibility/ test corpus.
- Safe `range` is registered via env override (no preprocess).
- Next: Phase 6 CompareDemo + screenshots.

## Security reminders

- Default `TemplateLoader` denies all includes.
- Do not log bearer tokens; API renderer scrubs tokens from errors.
- Prefer `DefaultAttributePolicy` for untrusted templates.
