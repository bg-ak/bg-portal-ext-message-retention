# Verification — version 0.2.0, 2026-09-28

Runtime remains IRIS 2026.1 build 234U (ARM64), IPM 0.10.9, and unchanged Portal
commit `1842205d2c200ab1d64b94b44dc4b7ef2394b2e4` in a disposable local instance.

| Check | Result |
| --- | --- |
| Upgrade from 0.1.0 | IPM load/compile/activation passed; existing 50-day rule, revision and seven fixture headers preserved |
| Original domain/lifecycle suite | 34 checks passed |
| Hourly policy suite | 13 checks passed: UTC year/leap-day rollover, strict cutoff, validation, unit changes, metadata and old payload compatibility |
| Business demo suite | 15 checks passed: nine messages, three policies, actual body summaries, expiry decisions, what-if values, saved-policy refresh and refusal paths |
| Seed helper | Created nine persistent synthetic bodies/headers and three named policies in USER |
| Limited-editor browser walkthrough | Showed the complete business dataset; changed GPS from 1 to 3 hours, previewed one match, saved, refreshed and observed the 2-hour position become within retention |
| Restore and screenshot | Restored the 1-hour GPS policy and captured all nine messages in `docs/preview.png` |
| Existing security setup | Browser used the existing limited editor and existing permissions; no new roles, grants or CSP applications were needed |

The suites total **62 checks**. Test data is rolled back; tests tolerate pre-existing
audit history and verify newly appended records by count difference. The screenshot
now uses the business demo itself, not the older technical integrity fixture.
The demo's displayed outcomes derive from saved policies and real header timestamps.
No deletion executor or scheduler was introduced. Native selection and UI behavior
are verified locally; production performance and destructive cleanup are not.

## Earlier 0.1.0 verification

The following record describes the original baseline, including security and
uninstall/reinstall checks. Those specific scenarios were not all repeated in 0.2.0.


## Pinned baseline

- Portal: `banksiaglobal/bg-portal`, `1842205d2c200ab1d64b94b44dc4b7ef2394b2e4`.
- Core classes and checked-in frontend: unmodified.
- Extension: its own `bg-portal-ext-message-retention` 0.1.0 ZPM package, API 2.
- Native runtime: IRIS 2026.1 build 234U, ARM64, official vendor image
  `sha256:a9453e8b58968411ae22c603a3431daff7cc101a27a337aa3b3d878c6c9eb921`.
- IPM/ZPM: 0.10.9.
- Data: synthetic fixtures only, in a disposable instance. `USER` held the browser
  demo; `RETENTIONTEST` used a separate globals database for a second complete run.

The published Portal image was inspected at
`sha256:213322e665d8137e3da4de7ab65c0383e58fbb64d27aff5ceadb633c9c59311b`;
its revision label matches the baseline. It is amd64-only and failed on this ARM
host with `Unsupported CPU`. Consequently the runtime proof uses the same source
loaded into native ARM IRIS, not a claim that the published image ran here.

## Executed checks

| Check | Result |
| --- | --- |
| ZPM load, compile, resource creation, activate | Passed |
| Registry module attribution | Separate extension package, enabled, compatible API 2 |
| Registry error/warning nodes | Both absent after actual use |
| Native test runner | **34 checks passed** in USER; final shell wrapper passed again in RETENTIONTEST |
| Demo test runner | **11 checks passed** in RETENTIONTEST, including refusal and rollback paths |
| Docker installation helper | Loaded the independent package in USER and checked the returned IPM status |
| Docker demo helper | Seeded 19 synthetic headers and 4 policies in RETENTIONTEST |
| Demo walkthrough values | Order: 1 day = 4, 50 days = 3, 365 days = 1; 50-day flags: 2 sessions, 1 shared body |
| Fixture rollback | USER header count returned to zero after first test run |
| Viewer security probe | Preview allowed, policy save denied for missing Edit resource |
| Revoked SQL SELECT | Preview failed closed |
| Revoked View resource | Domain, source adapter and page API denied access |
| Native browser flow | Discovery, 50-day preview, save, revision reload, outcome history passed as a limited editor |
| Final browser check | Existing limited editor loaded the final page and previewed the original seven-header verification fixture; screenshot in `docs/preview.png` |
| No frontend build | Existing checked-in Portal bundle used throughout |
| Disable / retire / re-enable | Direct page API blocked while inactive; data preserved |
| ZPM uninstall | Extension page class removed, core page class retained, nav entry absent |
| ZPM reinstall | 1 saved synthetic policy and all 4 pre-uninstall audit records preserved |
| SQL grants after reinstall | IRIS had dropped table grants; restoring the same grants restored limited-user access |
| Cross-namespace reads | Same class: USER matched 3, RETENTIONTEST matched 0; caller remained USER |
| Cross-namespace policy key | USER's 50-day policy and RETENTIONTEST's never policy remained distinct; probe mutation rolled back |

The 34 native checks cover integer validation, 1/50/365 days and never, leap-day and
exclusive cutoff behavior, duplicate create/stale revision rejection, exact class
filtering, a recent nonterminal header of another type in the same session, a missing
session, shared body outside the age window, class-qualified body IDs, `ENSPURGE=0`,
truncation and exact-limit distinction, SQL metacharacters as data, no header/body
deletion, audit counts and extension lifecycle access.

## Limits

The new four-policy demo dataset was checked through its native executable tests
and the seed helper. The final browser check used the existing seven-header test
fixture and existing limited-user permissions, not a new demo CSP application.

This is local verification, not TEST/LIVE evidence, a load test, a security audit,
or a validated selective purge algorithm. No actual production data was inspected
or changed. No message cleanup or scheduled task exists in this package.

The preview's bounded result size does not guarantee bounded SQL execution time.
Session, shared-body and class flags do not inspect body existence, stream ownership,
virtual-document search tables, application callbacks, business-process state,
external references, legal holds or concurrent resubmission. They are reasons for
review, not deletion authorization.

Source investigation of the installed stock purge supports the design decision;
it is not execution evidence for a custom purge. The extension never calls it.
