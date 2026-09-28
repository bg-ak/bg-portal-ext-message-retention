/// Extension-owned outcome history; no message payloads or header IDs are stored.
/// Ordinary application audit, not a tamper-proof replacement for IRIS system audit.
Class BG.Retention.Audit Extends %Persistent
{
Property AtUTC As %TimeStamp;
Property Actor As %String(MAXLEN = 128);
Property Operation As %String(MAXLEN = 32);
Property TargetNamespace As %String(MAXLEN = 64);
Property BodyClass As %String(MAXLEN = 220);
Property Details As %String(MAXLEN = 32000);
}
