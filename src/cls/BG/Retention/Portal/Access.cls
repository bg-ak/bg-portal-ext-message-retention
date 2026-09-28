/// Portal-specific lifecycle guard. Core resource checks do not block direct URLs
/// or custom WebMethods when a contribution is disabled or retired.
Class BG.Retention.Portal.Access Extends %RegisteredObject
{
ClassMethod Check()
{
    do ##class(BG.Retention.Service).Require()
    if '$listfind(##class(Portal.Ext.Registry).Contributions(), "BG.Retention.Portal.Contribution") {
        throw ##class(%Exception.General).%New("Message Retention extension is not active")
    }
}
}
