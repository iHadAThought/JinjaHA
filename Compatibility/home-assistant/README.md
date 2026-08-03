# Home Assistant helper parity

Add `.jinja` + `.expected.txt` pairs here when tracking HA templating changes.

Run via `CompatibilityHATests` in JinjaHATests (only pairs with `.expected.txt`).

## Work Audit board templates

`work_audit_*.jinja` are markdown card bodies mirrored from the paycheck-hours-audit Lovelace dashboard (ProxMox export: `paycheck_hours_audit.yaml`). They are **template-only** goldens: no frozen `.expected.txt` (output depends on entity state).

Assert local ↔ HA API parity with:

```bash
HA_URL=… HA_TOKEN=… swift test --filter LiveParityTests
```

Fixture snapshot: `Tests/JinjaHATests/Fixtures/snapshots/work_audit.json` (sanitized).

Regenerate the `.jinja` files when the live Work Audit markdown cards change.

See [`../TRACKED_DIFFERENCES.md`](../TRACKED_DIFFERENCES.md) and [`../../Docs/COMPAT.md`](../../Docs/COMPAT.md).
