/// Explicit, transactional synthetic data for a disposable Portal demonstration.
/// Not included in module.xml. Does not start a production or change security.
Class BG.RetentionDemo.Seed Extends %RegisteredObject
{
ClassMethod Run(confirmation As %String = "") As %Status
{
    set level=$tlevel
    try {
        if confirmation'="DISPOSABLE DEMO" {
            throw ##class(%Exception.General).%New("Use only in an isolated demo: confirmation must be DISPOSABLE DEMO")
        }
        do ##class(BG.Retention.Service).Require(1)
        if $get(^BG.RetentionDemo("seeded")) {
            throw ##class(%Exception.General).%New("Demo already seeded; reuse its data or start a fresh disposable instance")
        }
        set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Ens.MessageHeader")
        if rs.%SQLCODE<0 { throw ##class(%Exception.General).%New(rs.%Message) }
        if 'rs.%Next() || rs.%Get("N") {
            throw ##class(%Exception.General).%New("Demo requires an empty message header store; no existing data was changed")
        }
        if ##class(BG.Retention.Service).Rules($namespace).%Size() {
            throw ##class(%Exception.General).%New("Demo requires a namespace without retention policies")
        }
        tstart
        set now=$zdatetime($ztimestamp,3,1), session=9000
        for kind="Trace","Order","Receipt","Archive" {
            set class="BG.RetentionDemo."_kind
            for days=0,2,60,400 {
                set body=..Body(class), session=session+1
                do ..Header(class,body,session,9,##class(BG.Retention.Service).Cutoff(now,days))
                if (kind="Order") && (days=60) { set sharedBody=body }
                if (kind="Order") && (days=400) { set incompleteSession=session }
            }
            set keepDays=$select(kind="Trace":1,kind="Order":50,kind="Receipt":365,1:"")
            set mode=$select(kind="Archive":"never",1:"days")
            set sc=##class(BG.Retention.Service).Save($namespace,class,mode,keepDays,0)
            $$$ThrowOnError(sc)
        }
        // A recent header shares an aged order body, outside the age window.
        do ..Header("BG.RetentionDemo.Order",sharedBody,9100,9,now)
        // A recent queued trace keeps an aged order's session incomplete.
        do ..Header("BG.RetentionDemo.Trace",..Body("BG.RetentionDemo.Trace"),incompleteSession,2,now)
        // An aged order with no known session cannot be declared complete.
        do ..Header("BG.RetentionDemo.Order",..Body("BG.RetentionDemo.Order"),0,9,##class(BG.Retention.Service).Cutoff(now,100))
        set ^BG.RetentionDemo("seeded")=now
        tcommit
        write !,"RETENTION DEMO SEEDED: 19 headers, 4 policies in ",$namespace,!
        return $$$OK
    } catch ex {
        if $tlevel>level { trollback 1 }
        return ex.AsStatus()
    }
}

ClassMethod Body(class As %String) As %Integer
{
    set body=$classmethod(class,"%New"),body.Text="Synthetic BG Portal retention demo"
    set sc=body.%Save() $$$ThrowOnError(sc)
    return body.%Id()
}

ClassMethod Header(class As %String, body As %Integer, session As %Integer, status As %Integer, created As %TimeStamp)
{
    set header=##class(Ens.MessageHeader).%New()
    set header.MessageBodyClassName=class,header.MessageBodyId=body,header.SessionId=session
    set header.Status=status,header.TimeCreated=created,header.Type=1
    set sc=header.%Save() $$$ThrowOnError(sc)
}
}
