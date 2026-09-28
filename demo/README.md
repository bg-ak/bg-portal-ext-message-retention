# Demo guide

Install the extension first using the root [README](../README.md). Use a disposable
IRIS instance, an empty `Ens.MessageHeader` store, and no retention policies in the
target namespace. Synthetic data must not be mixed with a real production.

## Docker

```sh
sh demo/seed.sh YOUR_PORTAL_CONTAINER --disposable
```

The optional final argument selects another namespace. Its interoperability classes
and the retention service must be available there. The ordinary installation does
not import any `BG.RetentionDemo` or `BG.RetentionTests` classes.

## IRIS terminal

Copy the checkout to the server, select the namespace hosting Portal and run as
an administrator:

```objectscript
set sc=$system.OBJ.LoadDir("/absolute/path/to/bg-portal-ext-message-retention/demo/cls","ck",,1)
write $system.Status.GetErrorText(sc),!
// Continue only if compilation succeeded.
set sc=##class(BG.RetentionDemo.Seed).Run("DISPOSABLE DEMO")
write $system.Status.GetErrorText(sc),!
```

Success prints `RETENTION DEMO SEEDED: 19 headers, 4 policies in ...`.
The seed checks its preconditions before creating data and uses a transaction.
It refuses to overwrite policies or reseed an occupied namespace.

## Visitor walkthrough

In Portal open **Interoperability → Message retention**. Four policies are already
visible. Start with Order / 50 days: three headers match, two have incomplete or
unknown sessions, and one shares its body with another header outside the age
window. Switching the unsaved rule to 1 or 365 days changes the count to 4 or 1.

This explains the domain distinction: retention intent can be class-specific,
but message relationships cross class and age boundaries. A preview does not
authorize deletion. The page deliberately offers no cleanup button.

The Archive policy records “never”. Its class also has `ENSPURGE=0`, allowing the
page to explain that the IRIS parameter protects bodies, not their message headers.

To demonstrate the extension architecture, open Portal's **Extensions** page,
disable **Production Message Retention**, and reload. Its navigation and widget
disappear, and direct page/API access is denied. Re-enable it: the policies and
history remain. The Portal core and frontend have not been rebuilt.

## Hosting and resets

Use your existing Portal demo authentication. This repository does not change
users, passwords, CSP applications or public resource grants. For a restricted
demo account, follow [Access](../docs/OPERATIONS.md#access).

If the host rebuilds the demo periodically, include the package load and explicit
seed call in that host's setup sequence, **after** Portal is installed and before
visitors enter. There is no automatic seed hook in the extension.

For a clean reset, recreate the disposable instance and rerun installation/seed.
There is deliberately no script that deletes an existing message store. Disabling
or uninstalling the extension does not remove demo headers, policies or history.
Never use a broad purge command merely to reset this demonstration.
