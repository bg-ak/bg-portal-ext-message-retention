# Operations guide

For installation and the optional demo, start with the [README](../README.md).

## What you can do

- Store one policy per target namespace and exact `MessageBodyClassName`: 1–36,500
  elapsed days, or never. Unconfigured classes have no expiry in this planner.
- Discover body classes from up to 1,000 recent headers, or enter an exact class.
  Any persistent message class is accepted; it need not inherit `Ens.MessageBody`.
- Preview an unsaved rule. The UI reads at most 500 age-matched headers, including
  session-status and shared-body caution flags. The domain API supports 1–1,000.
- Distinguish a complete result from a lower bound. When another match exists,
  the UI says “at least”; caution counts cover only the displayed sample.
- See successful policy changes and completed previews in extension-owned history.
  Stale policy edits fail rather than silently overwriting a newer revision.

The timestamp basis is `Ens.MessageHeader.TimeCreated`, in UTC. A day means 24
hours and the cutoff is exclusive. This intentionally differs from the built-in
purge's local calendar-day calculation. Counts are **headers**, not distinct bodies,
sessions, bytes reclaimable, or messages proven safe to delete. A running production
can change the data during or after a scan.

## Access

Installation creates `BG_RetentionView` and `BG_RetentionEdit` with **no public
permissions**. It does not create users, grant roles or change an existing role.

An administrator must grant the intended role:

| Capability | Required access |
| --- | --- |
| Page, inventory, rules, preview, history | `BG_RetentionView:USE` |
| Save policy | Also `BG_RetentionEdit:USE` |
| Read header metadata | Database read access and SQL `SELECT` on `Ens.MessageHeader` in each target namespace |
| Read policies and history | SQL `SELECT` on `BG_Retention.Rule` and `BG_Retention.Audit` in Portal's namespace |
| Save policies | SQL `INSERT, UPDATE` on `BG_Retention.Rule` in Portal's namespace |
| Record completed preview / policy audit | Write access to the extension's storage database; Audit uses its object API |

Use existing site roles and database policies. A preview needs to append its history,
so its extension data store needs write access even though production data is read-only.
The current Portal CSP application's database role may already supply local database
access; it does not replace target-namespace SQL authorization. No `%All` is required.
The service never changes `$roles`, bypasses SQL privilege checking, opens message
bodies, or takes credentials from the browser.

## Use with existing message metadata

1. Load a production namespace for which you have the permissions above.
2. Discover message types, or enter an actual persistent body class.
3. Select days or never, then **Preview this rule**. Saving is not needed for what-if
   analysis. Try 1, 50 and 365 days; inspect the displayed cutoff and caution counts.
4. Save the planning policy. Open it from the policy list and preview it again.
5. Disable the extension on Portal's Extensions screen. Navigation and its widget
   disappear; direct page and WebMethod access are also denied by this extension.
6. Re-enable it. Its saved policies and history remain.

Preview is deliberately on-demand. `TOP` limits returned candidates, not database
work: sorting and checking all other headers in a session/body reference set can be
expensive. Start off-peak, inspect the query plan on your own data, and do not infer
production performance from the tiny verification fixture. There is no automatic
background scan and no statement timeout guarantee in this version.

## Headless use

The domain service has no dependency on Portal or Bloom:

```objectscript
// Run in the namespace where this module's code and policy storage are installed.
set sc = ##class(BG.Retention.Service).Save("MYPRODUCTION", "MyApp.Request", "days", 50, 0)
// Revision 0 creates; subsequent updates must pass the currently read Revision.
set rules = ##class(BG.Retention.Service).Rules("MYPRODUCTION")
set preview = ##class(BG.Retention.Service).Preview("MYPRODUCTION", "MyApp.Request", "days", 50, 500)
write preview.%ToJSON()
```

Portal lifecycle checks live in `BG.Retention.Portal.*`. Disabling its contribution
disables Portal entry points; the authorized headless planning service still exists.

## Disable, uninstall, reinstall

```objectscript
do ##class(Portal.Ext.Registry).SetEnabled("BG.Retention.Portal.Contribution", 0)
do ##class(Portal.Ext.Registry).SetEnabled("BG.Retention.Portal.Contribution", 1)
zpm "uninstall bg-portal-ext-message-retention"
zpm "load /absolute/path/to/bg-portal-ext-message-retention"
```

Disable/retire/uninstall do not deliberately erase policies, audit data or resource
definitions. Code removal and data survival were verified with IPM 0.10.9 on the
test runtime; retain a database backup before package changes on a real installation.
Package removal leaves data inaccessible until its classes are restored. IRIS drops
table SQL grants when the persistent classes are removed: after reinstall, reapply
the role-specific SQL grants above. Resource grants survive, but do not substitute
for these table privileges. No tasks are created, so there is no scheduler to stop. There is no “purge policy data” button.

Audit is ordinary application history, not a tamper-proof compliance log. Failed
requests are returned to the caller; only successful policy changes and completed
previews are recorded here. No message bodies or header IDs are stored in audit.

## Before adding an executor

A future executor needs its own reviewed IRIS-specific design: supported selection
API or validated adapter, shared-body safety, complete session/process handling,
search tables/streams, `ENSPURGE`, transactions and partial failure, concurrent
activity, policy revisions, revalidation immediately before deletion, auditable run
outcomes and reconciliation with existing purge tasks. Scheduling that executor
before these contracts exist would automate an unproven destructive operation.
