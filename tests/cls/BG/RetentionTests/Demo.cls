/// Verify real synthetic bodies, saved policies and displayed expiry decisions.
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
        do ##class(BG.RetentionTests.Fixture).Header("BG.RetentionTests.Message",##class(BG.RetentionTests.Fixture).Body("BG.RetentionTests.Message"),1,9,$zdatetime($ztimestamp,3,1))
        set sc=##class(BG.RetentionDemo.Seed).Run("DISPOSABLE DEMO")
        set refused=$$$ISERR(sc)&&(..Headers()=1)
        trollback 1
        do ..Assert(refused,"Demo refuses an occupied namespace without altering its header")
        set sc=##class(BG.Retention.Service).Save($namespace,"BG.RetentionDemo.FinancialDocument","never","",0) $$$ThrowOnError(sc)
        set sc=##class(BG.RetentionDemo.Seed).Run("DISPOSABLE DEMO")
        do ..Assert($$$ISERR(sc),"Demo refuses existing policies")
        trollback 1
        tstart
        set ^BG.RetentionTests("demoPassed")=3
        set sc=##class(BG.RetentionDemo.Seed).Run("DISPOSABLE DEMO")
        do ..Assert($$$ISOK(sc),"Documented business demo seed succeeds")
        do ..Assert((..Headers()=9)&&(##class(BG.Retention.Service).Rules($namespace).%Size()=3),"Demo creates nine messages and three policies")
        set d=##class(BG.RetentionDemo.Dataset).Read(),counts={}
        for i=0:1:d.rows.%Size()-1 { set row=d.rows.%Get(i) do counts.%Set(row.Decision,counts.%Get(row.Decision)+1) }
        do ..Assert((d.rows.%Size()=9)&&(counts.never=3)&&(counts.within=2)&&(counts.past=4),"Dataset shows three permanent, two current and four expired examples")
        do ..Assert(d.rows.%Get(0).Summary["INV-DEMO-101","Dataset reads the synthetic financial message content")
        do ..Assert(d.rows.%Get(3).Summary["DEMO-TRUCK-01","Dataset reads the synthetic GPS content")
        set p=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionDemo.FinancialDocument","never","")
        do ..Assert((p.matched=0)&&(p.cutoffUTC=""),"Accounting has no age expiry even for old documents")
        set p=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionDemo.TowTruckLocation","hours",1)
        do ..Assert(p.matched=2,"One-hour GPS rule matches two old positions")
        set p=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionDemo.TowTruckLocation","hours",3)
        do ..Assert(p.matched=1,"Three-hour what-if matches only the six-hour position")
        set p=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionDemo.TowTruckLocation","hours",12)
        do ..Assert(p.matched=0,"Twelve-hour what-if keeps all three positions")
        set p=##class(BG.Retention.Service).Preview($namespace,"BG.RetentionDemo.RecoveryStatus","days",50)
        do ..Assert(p.matched=2,"Fifty-day rule matches two old job updates")
        set sc=##class(BG.Retention.Service).Save($namespace,"BG.RetentionDemo.TowTruckLocation","hours",3,1,"Tow-truck GPS positions","Changed demo policy") $$$ThrowOnError(sc)
        set d=##class(BG.RetentionDemo.Dataset).Read()
        do ..Assert((d.rows.%Get(4).Decision="within")&&(d.rows.%Get(5).Decision="past"),"Refreshing dataset uses the edited policy, not hard-coded outcomes")
        set sc=##class(BG.RetentionDemo.Seed).Run("DISPOSABLE DEMO")
        do ..Assert($$$ISERR(sc)&&(..Headers()=9),"Preview, policy edits and reseed refusal leave every message intact")
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
