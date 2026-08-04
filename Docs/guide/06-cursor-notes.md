# Cursor notes / agent handoff

Handoff for the next Cursor agent after a local machine wipe. Keep library work in this repo; do **not** silently change consumer apps.

## Product stance

- **JinjaHA is the library**, not an app feature.
- Goal: documented HA Jinja/template surface in Swift; hybrid apps only fill `HAStateSnapshot` and use `LocalTemplateRenderer` + `FallbackTemplateRenderer`.
- **Permanent API-fallback (TD-009):** HACS, custom Jinja packages, arbitrary Python / CPython sandbox — never implement in-process.

## Current tip (as of 2026-08-04)

| Item | Value |
|------|--------|
| Public SPM | `https://github.com/iHadAThought/JinjaHA.git` `from: "0.3.0"` |
| Tip commit (library) | `665f19f` — guide handoff (on **v0.3.0** / `18ec286`) |
| Tags | `v0.1.0` … `v0.3.0` (latest **v0.3.0**) |
| Helper revision | `JinjaHAInfo.homeAssistantHelpersRevision = 9` |
| Core revision | `JinjaCoreInfo.implementationRevision = 8` |
| Active public branch | `cursor/github-library-release` (tracks public `main`) |
| Private `origin` | Fast-forward library tip onto `master`; keep lab branch intact |

## Remotes (do not confuse)

| Remote | Purpose |
|--------|---------|
| `github` | Public library-only history (scrubbed: no lab/VLAN/wiki-sync paths) |
| `origin` | Private mirror — may also hold lab branch history |

**Never** merge the HA Jinja lab branch into the public GitHub history. Lab stays private-only.

## Authorship (GitHub)

- Commits pushed to GitHub must be author/committer **iHadAThought** only (`140212683+iHadAThought@users.noreply.github.com`).
- No `Co-authored-by: Cursor` trailers on GitHub commits.
- Override local git identity when committing:  
  `git -c user.name='iHadAThought' -c user.email='140212683+iHadAThought@users.noreply.github.com' commit …`

## What shipped recently

1. Public library release + scrub (docs under `Docs/guide/`).
2. Catalog completeness Waves 0–2 + Phases 1–4 → **v0.3.0**.
3. Snapshot merge helpers + registry JSON decode + setup cookbook.
4. LiveParity helper strip (skips without `HA_URL`/`HA_TOKEN`).
5. `MinimalRender` optional hybrid when those env vars are set.

## Explicitly NOT done in library chats

- Wiring any Apple TV / dashboard **app** to JinjaHA (Phase 5 consumer) — separate project and chat.
- Pushing consumer apps to GitHub.
- Re-introducing lab/private hostnames into the public tree.

## Validate after clone

```bash
cd /path/to/JinjaHA
swift test          # offline suite; LiveParity skips without env
swift run MinimalRender
Scripts/check-compat-notes.sh
```

Live parity (optional lab):

```bash
HA_URL=… HA_TOKEN=… swift test --filter LiveParityTests
```

## Plans / memory locations

Cursor plan files (on the previous machine under `~/.cursor/plans/`):

- `jinjaha_completeness_phases.plan.md` — Phases 1–5 (5 deferred for apps)
- `ha_dashboard_hybrid_jinja_5732021f.plan.md` — library completeness (app todo cancelled)
- `github_library_release_a85fdf6a.plan.md` — public GitHub scrub/publish

In-repo truth: `Docs/FEATURES.md`, `Docs/COMPAT.md`, `Compatibility/TRACKED_DIFFERENCES.md`, this guide.

## Private wiki sync

- Product book name: **JinjaHA** (slug `jinjaha`).
- Guide sources: `Docs/guide/*.md` (this page included).
- Sync via API token env vars; LAN wiki CT/URL details live in the private Unifi / infra wiki books (not in this public tree).
- After pushing to private `origin`, refresh the JinjaHA wiki book.

## Next useful library tasks (optional)

- More Compatibility goldens per HA template-functions category.
- Expand LiveParity strip when lab is available.
- Deepen Partial helpers only when LiveParity or a real board fails.
- Consumer apps: **new chat / other repo** — pin `from: "0.3.0"`, map states → snapshot, `FallbackTemplateRenderer`.
