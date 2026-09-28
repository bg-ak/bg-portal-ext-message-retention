# Engineering assessment

## Decision

Build a real external **retention planner**, with persisted policies and a bounded
read-only analysis of actual headers. Do not call this version a retention engine.
It proves independent installation and native integration. It does not prove safe
class-selective cleanup, nor durable protection from another purge mechanism.

The management question is useful before deletion: which message classes do we have,
what retention do we intend, how many aged headers does a bounded analysis find,
and where do session/body relationships complicate that intent?

## IRIS findings

Read the installed 2026.1 build 234U definitions of `Ens.Util.MessagePurge`,
`Ens.MessageHeader`, `Ens.MessageHeaderBase`, `Ens.Util.Tasks.Purge`, and
`%SQL.Statement`. No vendor implementation is copied into this package.

| Finding | Consequence |
| --- | --- |
| Headers store `MessageBodyClassName` and `MessageBodyId` separately. Any persistent class can carry a message; derived `Ens.MessageBody` classes share an extent. | Policy identity is exact class plus namespace. Body-reference comparisons include class and ID. No arbitrary screen category or SQL table name is accepted from the client. |
| Public `Ens.Util.MessagePurge.Purge()` offers age and host filters, not a body-class filter or a preview/execution candidate contract. | Calling it once per class would still purge other classes. We do not use internal `generateDeleteSelectSQL` / `deleteDataUsingSelectQuery` methods as a public extension API. |
| Installed `KeepIntegrity` checks all headers in the session for statuses outside 4, 7, 8, 9. | Preview checks other types and newer headers in the same session. Missing/zero session and unknown status are flagged conservatively. These flags are not proof that business processes or external references can be removed. |
| Installed purge handles body deletion, search-table cleanup, header callbacks and bitmap maintenance. | A SQL DELETE or a loop over `%DeleteId` would not be an equivalent safe executor. |
| `ENSPURGE=0` prevents body purge, but headers can still be removed. | Surface it as a warning; never equate it with a “retain message forever” policy. |
| Multiple headers can reference one body; object/stream lifecycle may go beyond the body row. | Report any other header reference, even one outside this rule's time window. Do not estimate deleted bodies or reclaimed bytes. |
| The built-in day count uses a local calendar boundary; `TimeCreated` is UTC. | This planner states its own elapsed-day UTC rule and exact exclusive cutoff. It does not claim parity with a stock purge dry run. |

Primary references:

- [Message purge API](https://irisdocs.intersystems.com/irisforhealthlatest/csp/documatic/%25CSP.Documatic.cls?CLASSNAME=Ens.Util.MessagePurge&LIBRARY=ENSLIB)
- [Purging production data](https://irisdocs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=EGMG_purge)
- [Message storage and ENSPURGE](https://irisdocs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=EGDV_messages)
- [Header fields](https://docs.intersystems.com/irislatest/csp/documatic/%25CSP.Documatic.cls?CLASSNAME=Ens.MessageHeaderBase&LIBRARY=ENSLIB)

The online references are rolling documentation. Installed source, not a rolling
version label, grounds the 2026.1 findings above.

## Separation

`Rule`, `Audit`, `Service` and `Source` own domain policy, persistence and IRIS reads.
They have no `Portal.*` or Bloom calls. `Source` temporarily changes namespace with
`new $namespace`, uses checked, parameterized SQL, then restores the caller's
namespace. UI-supplied names are never SQL identifiers. The code and policy store
remain in the installation namespace.

`BG.Retention.Portal.*` owns the contribution, native shell page, dashboard widget
and Portal lifecycle guard. The only module dependency is `bg-portal-core`. No
production message classes, purge settings, roles or tasks are changed at install.

One query returns a bounded set of age-matched headers and correlated flags. The
extra row distinguishes a complete result from a lower bound. Shared-reference and
session checks intentionally inspect outside the age/class selection. There is no
“eligible” or “safe to delete” count. The result is an observation, not a durable
candidate list that could safely be executed later.

## Portal findings at 1842205

The extension model is sufficient for this vertical slice. Discovery, native shell,
page slots, PrimeVue controls, WebMethod proxying and ZPM module attribution work
without changing core. A page can also expose a widget slot for another extension.

The platform is a trusted in-process code extension system, not a sandbox. A
contribution can run code, supply `shell.head` scripts/styles and replace core items.
Installing a module therefore means trusting its publisher.

Four general limitations deserve upstream consideration:

1. **Lifecycle success:** `Registry.SyncClasses()` ignores `RunHook()` status and
   records the installed/upgraded version even after a failed hook. Small general
   fix: propagate failure and advance version only on success, allowing a retry.
   This package puts required resource creation in a ZPM `CheckStatus=true` invoke
   before activation instead of relying on discovery-time installation.
2. **Page ownership:** disable/retire/safe mode filters contributions, but does not
   make standalone page URLs or arbitrary custom WebMethods unavailable. Small
   general addition: an optional owner-contribution parameter on `Portal.Page`,
   checked by both render and broker hooks against active compatible contributions.
   For now the extension performs this check using the existing registry API.
3. **Audit outcomes:** generic actions log invocation and row JSON, not a committed
   result, and custom WebMethods have no shared audit service. A general operation
   audit API with explicit outcome would benefit unrelated extensions too. This
   package uses its own structured successful-outcome history, with no payloads.
4. **First-render broker availability:** `src/vue/main.ts` assigns `window.serverCall`
   after `app.mount()`. A mounted handler cannot immediately call a WebMethod.
   General fix: initialize the broker before mounting. This page follows core's
   existing `%OnNew` pattern and renders its initial data server-side.

Also, `REQUIRES` is informational. A page's `RESOURCE` and server-side service
checks do the actual authorization; client-side `when` does not. Resource filtering
of a contributed action is not a substitute for checking a custom endpoint.

None of these observations justifies adding retention-specific concepts to
`Portal.Core`. No core changes are included in this implementation.

## What this experiment establishes

An independent package can supply a project-specific IRIS management capability,
appear in Portal navigation and dashboard, use the existing shell and controls,
enforce its resources, persist and audit its own state, and be removed without
Portal knowing its classes in advance. This is a concrete positive result for
the platform claim.

The destructive half of the original hypothesis exposes an IRIS/domain contract
gap rather than a missing Portal screen slot. An honest contest demonstration should
show the actual planning workflow and the refusal to invent a purge contract.
If the demonstration must include scheduled class-specific deletion, this slice
is insufficient; a separately reviewed executor is required first.
