/// Verify the documented demo recipe; all data is rolled back.
Class BG.RetentionTests.Demo Extends %RegisteredObject
{
ClassMethod Assert(ok As %Boolean, message As %String)
{
    if 'ok { throw ##class(%Exception.General).%New("FAILED: "_message) }
    set ^BG.RetentionTests("demoPassed")=$get(^BG.RetentionTests("demoPassed"))+1
    write "PASS: ",message,!
}

ClassMethod Headers() As %Integer
{
    set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Ens.MessageHeader")
    if rs.%SQLCODE<0 { throw ##class(%Exception.General).%New(rs.%Message) }
    do rs.%Next()
    return rs.%Get("N")
}

ClassMethod Run() As %Status
{
    set level=$tlevel
    try {
        if $get(^BG.RetentionTests("allowFixtures"))'=1 { throw ##class(%Exception.General).%New("Use disposable-instance test instructions") }
        if ..Headers() { throw ##class(%Exception.General).%New("Tests require an empty header store") }
        tstart
        set ^BG.RetentionTests("demoPassed")=0
        set sc=##class(BG.RetentionDemo.Seed).Run()
        do ..Assert($$$ISERR(sc),"Demo requires explicit confirmation")
        tstart
        do ##class(BG.RetentionDemo.Seed).Header("BG.RetentionDemo.Trace",##class(BG.RetentionDemo.Seed).Body("BG.RetentionDemo.Trace"),1,9,$zdatetime($ztimestamp,3,1))
        set sc=##class(BG.RetentionDemo.Seed).Run("DISPOSABLE DEMO")
        set refused=$$$ISERR(sc)&&(..Headers()=1)
        trollback 1
        do ..Assert(refused,"Demo refuses an occupied namespace without altering its header")
        set sc=##class(BG.Retention.Service).Save($namespace,"BG.RetentionDemo.Trace","days",1,0)
        $$$ThrowOnError(sc)
        set sc=##class(BG.RetentionDemo.Seed).Run("DISPOSABLE DEMO")
        do ..Assert($$$ISERR(sc),"Demo refuses existing policies")
        // Roll back the refusal probes and begin an independent seeding test.
        trollback 1
        tstart
        set ^BG.RetentionTests("demoPassed")=3
        set sc=##class(BG.RetentionDemo.Seed).Run("DISPOSABLE DEMO")
        do ..Assert($$$ISOK(sc),"Documented demo seed succeeds")
        do ..Assert(..Headers()=19,"Demo creates exactly 19 headers")
        do ..Assert(##class(BG.Retention.Service).Rules($namespace).%Size()=4,"Demo creates four policies")
        set p=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionDemo.Order","days",50)
        do ..Assert((p.matched=3)&&(p.sessionBlocked=2)&&(p.sharedBody=1),"50-day demo: three headers, two session flags, one shared body")
        set p=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionDemo.Order","days",1)
        do ..Assert(p.matched=4,"One-day what-if finds four order headers")
        set p=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionDemo.Order","days",365)
        do ..Assert(p.matched=1,"One-year what-if finds one order header")
        set p=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionDemo.Archive","never","")
        do ..Assert((p.matched=0)&&(p.cutoffUTC="")&&p.classInfo.purgeProtected,"Archive records never and independently reports ENSPURGE")
        set sc=##class(BG.RetentionDemo.Seed).Run("DISPOSABLE DEMO")
        do ..Assert($$$ISERR(sc)&&(..Headers()=19),"Repeated seeding refuses to duplicate or remove data")
        set total=^BG.RetentionTests("demoPassed")
        trollback 1
        write "RETENTION DEMO TESTS PASSED: ",total,!
        return $$$OK
    } catch ex {
        while $tlevel>level { trollback 1 }
        write $system.Status.GetErrorText(ex.AsStatus()),!
        return ex.AsStatus()
    }
}
}
