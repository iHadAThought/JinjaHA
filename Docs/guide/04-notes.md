# Notes

Working notes for the JinjaHA project.

## 2026-08-04 (machine wipe handoff)

- Library tip: **v0.3.0** (`JinjaHAInfo.homeAssistantHelpersRevision` = 9, JinjaCore implementationRevision = 8).
- Public GitHub and private `origin` should both carry the library tip after this sync.
- See **Cursor notes / agent handoff** page for remotes, branches, authorship, and next steps.
- App hybrid wiring (tvOS dashboard consumer) is **out of scope** for library-only chats.

## 2026-08-02

- Phase 0–7 complete: engine, helpers, corpus, CompareDemo, COMPAT upstream process.
- Public package: https://github.com/iHadAThought/JinjaHA
- Re-check Pallets/HA docs ≤ every 90 days (`Scripts/check-compat-notes.sh`).
- Track intentional divergences in `Compatibility/TRACKED_DIFFERENCES.md`.

## Security reminders

- Default `TemplateLoader` denies all includes.
- Do not log bearer tokens; API renderer scrubs tokens from errors.
- Prefer `DefaultAttributePolicy` for untrusted templates.
- Never commit tokens or LAN/lab inventory into the public GitHub tree.
