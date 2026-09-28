/// ENSPURGE affects bodies only; a never policy and body protection are different.
Class BG.RetentionDemo.Archive Extends %Persistent
{
Parameter ENSPURGE = 0;
Property Text As %String;
}
