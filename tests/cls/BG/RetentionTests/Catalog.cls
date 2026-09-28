Class BG.RetentionTests.Catalog Extends %RegisteredObject
{
ClassMethod Assert(ok As %Boolean, message As %String)
{
    if 'ok { throw ##class(%Exception.General).%New("FAILED: "_message) }
    set ^BG.RetentionTests("catalogPassed")=$get(^BG.RetentionTests("catalogPassed"))+1
    write "PASS: ",message,!
}
ClassMethod Find(rows As %DynamicArray, name As %String) As %DynamicObject
{
    for i=0:1:rows.%Size()-1 { set r=rows.%Get(i) if r.BodyClass=name { return r } }
    return {}
}
/// May run alongside the synthetic demo. Unique fixture classes are guarded and all writes roll back.
ClassMethod Run() As %Status
{
    set level=$tlevel
    try {
        if $get(^BG.RetentionTests("allowFixtures"))'=1 { throw ##class(%Exception.General).%New("Use disposable-instance test instructions") }
        set a="BG.RetentionTests.Message",b="BG.RetentionTests.Other",c="BG.RetentionTests.Protected"
        set original=##class(BG.Retention.Service).Rules($namespace)
        if ..Find(original,a).%IsDefined("Revision") || ..Find(original,b).%IsDefined("Revision") || ..Find(original,c).%IsDefined("Revision") {
            throw ##class(%Exception.General).%New("Catalog fixture policies already exist")
        }
        tstart
        set ^BG.RetentionTests("catalogPassed")=0,now=$zdatetime($ztimestamp,3,1)
        set audit=##class(BG.RetentionTests.Runner).AuditCount()
        set sc=##class(BG.Retention.Service).Save($namespace,c,"never","",0,"Saved-only type") $$$ThrowOnError(sc)
        // Only two newest headers are discovered; the saved-only class must still appear.
        do ##class(BG.RetentionTests.Fixture).Header(a,1,9701,9,now)
        do ##class(BG.RetentionTests.Fixture).Header(b,1,9702,9,now)
        do ##class(BG.RetentionTests.Fixture).Header(a,1,9703,9,now)
        set result=##class(BG.Retention.Service).Catalog($namespace,2)
        do ..Assert(result.truncated && (result.headersInspected=2),"Catalog exposes partial discovery")
        do ..Assert(result.types.%Size()=(original.%Size()+3),"Observed and saved-only types are merged without duplicates")
        set row=..Find(result.types,c)
        do ..Assert((row.Mode="never")&&(row.DisplayName="Saved-only type"),"Saved-only type retains its rule and label")
        set row=..Find(result.types,a)
        do ..Assert((row.Mode="")&&(row.KeepFor="")&&(row.Revision=0),"Unconfigured observed type has no implicit retention period")
        do ..Assert(##class(BG.Retention.Service).Rules($namespace).%Size()=(original.%Size()+1),"Reading catalog does not create policies")
        do ..Assert(##class(BG.RetentionTests.Runner).AuditCount()=(audit+1),"Discovery does not run previews or append preview audit")
        set sc=##class(BG.Retention.Service).Save($namespace,a,"hours",3,0,"GPS test") $$$ThrowOnError(sc)
        set result=##class(BG.Retention.Service).Catalog($namespace,2),row=..Find(result.types,a)
        do ..Assert((row.Mode="hours")&&(row.KeepFor=3)&&(row.Revision=1),"Saving an observed type populates the same catalog row")
        do ..Assert(..Find(result.types,b).Mode="","Saving one type leaves another unconfigured")
        do ..Assert(..Find(result.types,c).Mode="never","Saving one type preserves other saved rules")
        do ..Assert(result.types.%Size()=(original.%Size()+3),"Saved and discovered instance of a class remains one row")
        set bad=0
        try { set ignore=##class(BG.Retention.Service).Catalog($namespace,1001) } catch ex { set bad=1 }
        do ..Assert(bad,"Catalog preserves discovery limit validation")
        set total=^BG.RetentionTests("catalogPassed")
        trollback 1
        write "RETENTION CATALOG TESTS PASSED: ",total,!
        return $$$OK
    } catch ex {
        if $tlevel>level { trollback 1 }
        write $system.Status.GetErrorText(ex.AsStatus()),!
        return ex.AsStatus()
    }
}
}
