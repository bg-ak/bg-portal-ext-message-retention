/// Planning policy, not an instruction to the built-in IRIS purge task.
Class BG.Retention.Rule Extends %Persistent
{
Property TargetNamespace As %String(MAXLEN = 64) [ Required ];
Property BodyClass As %String(MAXLEN = 220) [ Required ];
Property Mode As %String(VALUELIST = ",days,never") [ Required ];
Property KeepDays As %Integer(MINVAL = 1, MAXVAL = 36500);
Property Revision As %Integer [ InitialExpression = 1 ];
Property UpdatedAt As %TimeStamp;
Property UpdatedBy As %String(MAXLEN = 128);
Index Identity On (TargetNamespace, BodyClass) [ Unique ];
}
