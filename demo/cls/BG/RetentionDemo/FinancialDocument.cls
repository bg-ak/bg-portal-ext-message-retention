/// Synthetic financial message; its type is the policy identity.
Class BG.RetentionDemo.FinancialDocument Extends %Persistent
{
Property DocumentNumber As %String;
Property EntryType As %String;
Property Amount As %Numeric(SCALE = 2);
Property Currency As %String;
}
