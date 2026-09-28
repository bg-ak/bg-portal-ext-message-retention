Class BG.RetentionTests.Hours Extends %RegisteredObject
{
ClassMethod Assert(ok As %Boolean, message As %String)
{
    if 'ok { throw ##class(%Exception.General).%New("FAILED: "_message) }
    set ^BG.RetentionTests("hourPassed")=$get(^BG.RetentionTests("hourPassed"))+1
    write "PASS: ",message,!
}
ClassMethod Run() As %Status
{
    set level=$tlevel
    try {
        if $get(^BG.RetentionTests("allowFixtures"))'=1 { throw ##class(%Exception.General).%New("Use disposable-instance test instructions") }
        tstart
        set ^BG.RetentionTests("hourPassed")=0,class="BG.RetentionTests.Message"
        do ..Assert(##class(BG.Retention.Service).Cutoff("2026-01-01 00:30:00",1,"hours")="2025-12-31 23:30:00","Hour cutoff crosses year boundary")
        do ..Assert(##class(BG.Retention.Service).Cutoff("2024-03-01 00:30:00",1,"hours")="2024-02-29 23:30:00","Hour cutoff crosses leap-day midnight")
        set sc=##class(BG.Retention.Service).Save($namespace,class,"days",50,0) $$$ThrowOnError(sc)
        set r=##class(BG.Retention.Service).Rules($namespace).%Get(0)
        do ..Assert((r.KeepDays=50)&&(r.KeepFor=50),"Existing day API and KeepDays remain compatible")
        set sc=##class(BG.Retention.Service).Save($namespace,class,"hours",1,1,"GPS positions","Recent locations support dispatch") $$$ThrowOnError(sc)
        set r=##class(BG.Retention.Service).Rules($namespace).%Get(0)
        do ..Assert((r.KeepHours=1)&&(r.KeepFor=1)&&(r.KeepDays=""),"Changing to hours clears stale days")
        do ..Assert((r.DisplayName="GPS positions")&&(r.Reason="Recent locations support dispatch"),"Policy name and reason are persisted")
        for amount=0,-1,0.5,876001,"abc" {
            set sc=##class(BG.Retention.Service).Save($namespace,class,"hours",amount,2)
            do ..Assert($$$ISERR(sc),"Reject invalid hours "_amount)
        }
        set cutoff=##class(BG.Retention.Service).Cutoff("2026-01-01 00:30:00",1,"hours")
        do ##class(BG.RetentionTests.Fixture).Header(class,##class(BG.RetentionTests.Fixture).Body(class),9601,9,cutoff)
        do ##class(BG.RetentionTests.Fixture).Header(class,##class(BG.RetentionTests.Fixture).Body(class),9602,9,"2025-12-31 23:29:59")
        set p=##class(BG.Retention.Source).Scan($namespace,class,cutoff,500)
        do ..Assert(p.matched=1,"Hour selection excludes exact boundary and includes the previous second")
        set sc=##class(BG.Retention.Service).Save($namespace,class,"never","",2) $$$ThrowOnError(sc)
        set r=##class(BG.Retention.Service).Rules($namespace).%Get(0)
        do ..Assert((r.KeepDays="")&&(r.KeepHours=""),"Never clears both duration fields")
        do ..Assert(##class(BG.Retention.Portal.Page).Amount({"Mode":"days","KeepDays":50})=50,"Old day-only WebMethod payload remains valid")
        set total=^BG.RetentionTests("hourPassed")
        trollback 1
        write "RETENTION HOUR TESTS PASSED: ",total,!
        return $$$OK
    } catch ex {
        if $tlevel>level { trollback 1 }
        write $system.Status.GetErrorText(ex.AsStatus()),!
        return ex.AsStatus()
    }
}
}
