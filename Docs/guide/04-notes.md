# Notes

Working notes for the JinjaHA project.

## 2026-08-02

- Phase 0–7 complete: engine, helpers, corpus, CompareDemo, COMPAT upstream process.
- Public package: https://github.com/iHadAThought/JinjaHA
- Re-check Pallets/HA docs ≤ every 90 days (`Scripts/check-compat-notes.sh`).
- Track intentional divergences in `Compatibility/TRACKED_DIFFERENCES.md`.

## Security reminders

- Default `TemplateLoader` denies all includes.
- Do not log bearer tokens; API renderer scrubs tokens from errors.
- Prefer `DefaultAttributePolicy` for untrusted templates.
