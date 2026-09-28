# Limited-user verification

Run only on a fresh disposable instance with the extension and test classes loaded.
Seed `Fixture.Seed()` as described in the package README. These probes need the
seven synthetic headers; the ordinary runner rolls its fixtures back.

Create dedicated viewer/editor roles and users in `%SYS`, using your throwaway test
password. No existing users, CSPSystem permissions or password policies need to
change. Role names must differ from user names.

```objectscript
zn "%SYS"
set testPassword = "REPLACE_WITH_THROWAWAY_TEST_PASSWORD"
set sc = ##class(Security.Roles).Create("RetentionTestViewer", "Disposable test viewer", "BG_RetentionView:U,%DB_USER:RW")
set sc = ##class(Security.Roles).Create("RetentionTestEditor", "Disposable test editor", "BG_RetentionView:U,BG_RetentionEdit:U,%DB_USER:RW")
set sc = ##class(Security.Users).Create("rtviewer", "RetentionTestViewer", testPassword, "Disposable test viewer")
set sc = ##class(Security.Users).Create("rteditor", "RetentionTestEditor", testPassword, "Disposable test editor")
// Inspect each sc; do not continue on an error.
zn "USER"
do ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON Ens.MessageHeader TO RetentionTestViewer,RetentionTestEditor").%Display()
do ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON BG_Retention.Rule TO RetentionTestViewer,RetentionTestEditor").%Display()
do ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON BG_Retention.Audit TO RetentionTestViewer,RetentionTestEditor").%Display()
do ##class(%SQL.Statement).%ExecDirect(, "GRANT INSERT,UPDATE ON BG_Retention.Rule TO RetentionTestEditor").%Display()
```

Run the login and probe **on one terminal command line**, then halt. The limited
users intentionally have no Terminal service access, so returning to the interactive
prompt after login would end that session. This does not grant them terminal access.

```objectscript
write $system.Security.Login("rtviewer",testPassword),! write $system.Status.GetErrorText(##class(BG.RetentionTests.SecurityProbe).Viewer()),! halt
```

Expected marker: `SECURITY VIEWER PASSED: preview allowed, save denied`.

In another administrative session, revoke SELECT from **that test role only**:

```objectscript
do ##class(%SQL.Statement).%ExecDirect(, "REVOKE SELECT ON Ens.MessageHeader FROM RetentionTestViewer").%Display()
```

Log in and invoke `SecurityProbe.NoSQL()` on one line as above. Expected:
`SECURITY SQL PASSED: missing SELECT fails closed`. Restore the same SELECT grant.

For resource revocation, in `%SYS` modify the disposable viewer role's `Resources`
to `%DB_USER:RW`, removing `BG_RetentionView:U`. Log in afresh and call
`SecurityProbe.NoView()`. Expected:
`SECURITY RESOURCE PASSED: domain, source and page deny access`.
Restore its original resources afterwards.

For browser testing use a standard password-authenticated Portal application. The
repository's optional demo login requires additional CSPSystem setup; a normal IRIS
login page avoids that dependency. On this disposable instance only, setting its
`LoginPage` to an empty string uses the standard login. Authentication and CSRF stay
enabled. Verify editor save/preview and viewer preview/no save button.

Destroy the disposable instance when done; none of these test roles or passwords
belongs in an ordinary installation.
