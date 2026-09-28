/// Explicit transactional demo, outside the installed extension package.
Class BG.RetentionDemo.Seed Extends %RegisteredObject
{
ClassMethod Run(confirmation As %String = "") As %Status
{
    set level=$tlevel
    try {
        if confirmation'="DISPOSABLE DEMO" { throw ##class(%Exception.General).%New("Use an isolated demo and confirm DISPOSABLE DEMO") }
        do ##class(BG.Retention.Service).Require(1)
        if $get(^BG.RetentionDemo("seeded")) { throw ##class(%Exception.General).%New("Demo already seeded; use a fresh disposable instance for the new dataset") }
        set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Ens.MessageHeader")
        if rs.%SQLCODE<0 { throw ##class(%Exception.General).%New(rs.%Message) }
        if 'rs.%Next() || rs.%Get("N") { throw ##class(%Exception.General).%New("Demo requires an empty message header store") }
        if ##class(BG.Retention.Service).Rules($namespace).%Size() { throw ##class(%Exception.General).%New("Demo requires a namespace without retention policies") }
        tstart
        set now=$zdatetime($ztimestamp,3,1)
        set sc=##class(BG.Retention.Service).Save($namespace,"BG.RetentionDemo.FinancialDocument","never","",0,"Accounting documents","Keep financial history for reconciliation and review; no expiry in this example.") $$$ThrowOnError(sc)
        set sc=##class(BG.Retention.Service).Save($namespace,"BG.RetentionDemo.TowTruckLocation","hours",1,0,"Tow-truck GPS positions","Live dispatch needs recent positions; older coordinates quickly lose their value.") $$$ThrowOnError(sc)
        set sc=##class(BG.Retention.Service).Save($namespace,"BG.RetentionDemo.RecoveryStatus","days",50,0,"Towing status updates","Keep recent job history for service enquiries, then review it for cleanup.") $$$ThrowOnError(sc)
        for i=1:1:3 {
            set b=##class(BG.RetentionDemo.FinancialDocument).%New()
            set b.DocumentNumber=$piece("INV-DEMO-101|PAY-DEMO-202|JRN-DEMO-303","|",i),b.EntryType=$piece("Invoice|Payment received|Ledger adjustment","|",i)
            set b.Amount=$piece("240|180|35","|",i),b.Currency="USD"
            do ..Message(b,##class(BG.Retention.Service).Cutoff(now,$piece("400|30|2","|",i)),9200+i)
        }
        for i=1:1:3 {
            set b=##class(BG.RetentionDemo.TowTruckLocation).%New(),b.VehicleId="DEMO-TRUCK-01"
            set b.Latitude=41.710000+(i*.001),b.Longitude=44.800000+(i*.002)
            set created=$select(i=1:..MinutesAgo(now,10),1:##class(BG.Retention.Service).Cutoff(now,$select(i=2:2,1:6),"hours"))
            do ..Message(b,created,9300+i)
        }
        for i=1:1:3 {
            set b=##class(BG.RetentionDemo.RecoveryStatus).%New(),b.JobReference="DEMO-JOB-"_(100+i)
            set b.StatusLabel=$piece("Vehicle delivered|Tow completed|Job closed","|",i)
            do ..Message(b,##class(BG.Retention.Service).Cutoff(now,$piece("2|60|400","|",i)),9400+i)
        }
        set ^BG.RetentionDemo("seeded")=now,^BG.RetentionDemo("version")="0.2.0"
        tcommit
        write !,"RETENTION DEMO SEEDED: 9 messages, 3 policies in ",$namespace,!
        return $$$OK
    } catch ex {
        if $tlevel>level { trollback 1 }
        return ex.AsStatus()
    }
}

ClassMethod MinutesAgo(asOf As %String, minutes As %Integer) As %String
{
    set h=$zdatetimeh(asOf,3),seconds=($piece(h,",")*86400)+$piece(h,",",2)-(minutes*60)
    return $zdatetime((seconds\86400)_","_(seconds#86400),3,1)
}

ClassMethod Message(body As %Persistent, created As %TimeStamp, session As %Integer)
{
    set sc=body.%Save() $$$ThrowOnError(sc)
    set h=##class(Ens.MessageHeader).%New()
    set h.MessageBodyClassName=body.%ClassName(1),h.MessageBodyId=body.%Id(),h.TimeCreated=created,h.SessionId=session,h.Status=9,h.Type=1
    set sc=h.%Save() $$$ThrowOnError(sc)
    set ^BG.RetentionDemo("headers",h.%Id())=1
}
}
