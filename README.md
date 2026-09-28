# Production Message Retention for BG Portal

An independent extension for [Sergei's BG Portal](https://github.com/banksiaglobal/bg-portal).
Choose retention periods by production message body class and preview the affected
headers inside Portal's own navigation, page layout and dashboard.

A practical companion to Portal's extension model: its own repository, ZPM package,
domain service and data, with **no changes to Portal core or frontend**.

**Version 0.1.0 plans retention; it does not delete messages or schedule cleanup.**
“Never expire” records an intention and does not override existing IRIS purge jobs.
The [engineering assessment](DESIGN.md) explains the integrity constraints and why
deletion needs a separate design.

![Read-only preview on synthetic verification messages](docs/preview.png)

## Add it to an existing Portal

Requirements:

- IRIS with interoperability available in the Portal namespace.
- `bg-portal-core` 0.1.x, extension API 2. Tested on
  [Portal commit 1842205](https://github.com/banksiaglobal/bg-portal/commit/1842205d2c200ab1d64b94b44dc4b7ef2394b2e4).
  Use that commit or a newer build with the same page/broker resource checks;
  the core's `0.1.0` version alone does not distinguish earlier builds.
- ZPM/IPM enabled in that namespace. The Docker helper is tested with IPM 0.10.9.
- An administrator to install the package and grant access.

For a running Portal Docker container:

```sh
git clone https://github.com/bg-ak/bg-portal-ext-message-retention.git
cd bg-portal-ext-message-retention
sh scripts/install.sh YOUR_PORTAL_CONTAINER
```

Replace `YOUR_PORTAL_CONTAINER` with its name from `docker ps`. The default
namespace is `USER`; pass another namespace as the second argument if needed.
The helper copies only the manifest and extension source, calls IPM and verifies
its returned status.
It does not change Portal source, authentication, roles or existing purge settings.

For an installation without Docker, copy this checkout to the IRIS server and run
in the namespace hosting Portal:

```objectscript
zpm "load /absolute/path/to/bg-portal-ext-message-retention"
```

This repository is the installation source. The package has **not** been published
to a ZPM registry, so use `load`, not `install bg-portal-ext-message-retention`.
No npm build is needed.

Sign in to Portal and open **Interoperability → Message retention**, or append
`/csp/portal/BG.Retention.Portal.Page.cls` to your Portal origin. A dashboard widget
also links to it, and **Extensions** identifies the separate module.

Installation creates `BG_RetentionView` and `BG_RetentionEdit` with no public grants.
An administrator can try the disposable demo immediately. For ordinary users,
apply the [role and SQL permissions](docs/OPERATIONS.md#access) to the intended role.

## Try the demonstration in a minute

Use an **isolated demo instance with no existing message headers or retention
policies**. Demo data is optional and is not installed by the ZPM module.

```sh
sh demo/seed.sh YOUR_PORTAL_CONTAINER --disposable
```

For a non-default namespace, append its name after `--disposable`.
The seed creates 19 synthetic headers and their bodies plus four policies:

| Message body class | Retention | What it illustrates |
| --- | --- | --- |
| `BG.RetentionDemo.Trace` | 1 day | Short-lived diagnostic messages |
| `BG.RetentionDemo.Order` | 50 days | Shared bodies and incomplete sessions |
| `BG.RetentionDemo.Receipt` | 365 days | Longer retention |
| `BG.RetentionDemo.Archive` | Never | No age expiry; separate `ENSPURGE=0` warning |

1. Open **Message retention**, then open the `BG.RetentionDemo.Order` policy.
2. Click **Preview this rule**. Expect **3 age-matched headers**, **2 incomplete /
   unknown session flags**, and **1 shared-body flag**.
3. Change days to **1** and preview: expect **4** headers. Change to **365**:
   expect **1**. These are what-if previews; saving is optional.
4. Open **Archive** and preview: no age expiry and no scan. Its `ENSPURGE=0`
   warning explains that native body protection does not preserve the headers.
5. Save a policy change and inspect **Recent activity**. Messages remain intact.

Counts above apply immediately after seeding. Flags can overlap; they are not a
count of messages proven safe to delete. Days are elapsed 24-hour periods in UTC.

The seed refuses occupied namespaces and repeated runs, and commits its data and
policies together. It does not run a production, create users or delete anything.
For server-side commands, demo resets and a lifecycle walkthrough, see
[the demo guide](demo/README.md).

## Verify

Run before seeding the visual demo, on a disposable instance with the extension
installed and an empty header/policy store:

```sh
sh tests/run.sh YOUR_DISPOSABLE_CONTAINER --disposable
```

Expected: `RETENTION TESTS PASSED: 34` and `RETENTION DEMO TESTS PASSED: 11`.
Both suites roll back their fixture data. The wrapper requires explicit success
markers as well as a successful process exit. See the
[verification record](VERIFICATION.md) and [limited-user probes](tests/SECURITY.md).

## How it fits together

- `src/cls/BG/Retention/`: policies, audit history and IRIS header analysis.
- `src/cls/BG/Retention/Portal/`: native page, navigation, widget and lifecycle guard.
- `module.xml`: independently installable package; depends on `bg-portal-core`.
- `demo/`: optional synthetic data, outside the installed package.
- `tests/`: executable domain, lifecycle and demo checks.

The domain service does not depend on Portal or Bloom. Read the
[operations guide](docs/OPERATIONS.md) for headless calls, authorization, bounded
queries and uninstall/reinstall, and [DESIGN.md](DESIGN.md) for the architecture
assessment and possible general improvements to the extension API.

## License

Copyright (C) 2026 Alexander Kolesov. [GNU AGPL version 3](LICENSE).
BG Portal is a separate project by its respective authors, with its own license.
