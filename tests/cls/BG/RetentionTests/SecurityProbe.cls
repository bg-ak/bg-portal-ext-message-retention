/// Invoke in a fresh process logged in as the disposable viewer (see tests/run.sh).
Class BG.RetentionTests.SecurityProbe Extends %RegisteredObject
{
ClassMethod Viewer() As %Status
{
    try {
        if $system.Security.Check("BG_RetentionEdit","USE") { throw ##class(%Exception.General).%New("Probe needs a viewer without Edit") }
        set result=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionTests.Message","days",50)
        if result.matched'=3 { throw ##class(%Exception.General).%New("Viewer preview failed") }
        set sc=##class(BG.Retention.Service).Save($namespace,"BG.RetentionTests.Message","days",1,0)
        if $$$ISOK(sc) { throw ##class(%Exception.General).%New("Viewer was able to save") }
        if $system.Status.GetErrorText(sc)'["BG_RetentionEdit" { throw ##class(%Exception.General).%New("Write failed for the wrong reason") }
        write "SECURITY VIEWER PASSED: preview allowed, save denied",!
        return $$$OK
    } catch ex { return ex.AsStatus() }
}

/// Same viewer with SELECT on Ens.MessageHeader revoked. Must fail, not return zero rows.
ClassMethod NoSQL() As %Status
{
    set denied=0
    try { set result=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionTests.Message","days",50) }
    catch ex { set denied=1 }
    return:'denied $$$ERROR($$$GeneralError,"Header SELECT was bypassed")
    write "SECURITY SQL PASSED: missing SELECT fails closed",!
    return $$$OK
}

/// Same account with View resource revoked, including direct service and source calls.
ClassMethod NoView() As %Status
{
    set denied=0
    try { set result=##class(BG.Retention.Service).Rules($namespace) }
    catch ex { set denied=denied+1 }
    try { set result=##class(BG.Retention.Source).Scan($namespace,"BG.RetentionTests.Message","2026-09-28 00:00:00",10) }
    catch ex { set denied=denied+1 }
    set result={}.%FromJSON(##class(BG.Retention.Portal.Page).ReadView($namespace))
    if 'result.ok { set denied=denied+1 }
    return:denied'=3 $$$ERROR($$$GeneralError,"View resource was bypassed")
    write "SECURITY RESOURCE PASSED: domain, source and page deny access",!
    return $$$OK
}
}
