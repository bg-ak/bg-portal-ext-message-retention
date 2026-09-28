Class BG.RetentionTests.Fixture Extends %RegisteredObject
{
/// Explicit opt-in and empty header store. Never run in a production namespace.
ClassMethod Seed()
{
    if $get(^BG.RetentionTests("allowFixtures"))'=1 {
        throw ##class(%Exception.General).%New("Fixtures require explicit opt-in in a disposable instance")
    }
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM Ens.MessageHeader")
    if 'rs.%Next() || rs.%Get("N") { throw ##class(%Exception.General).%New("Fixture needs an empty header store") }
    set old = ##class(BG.Retention.Service).Cutoff($zdatetime($ztimestamp,3,1),100)
    set recent = $zdatetime($ztimestamp,3,1)
    set a = ..Body("BG.RetentionTests.Message"), b = ..Body("BG.RetentionTests.Other"), p = ..Body("BG.RetentionTests.Protected")
    set ^BG.RetentionTests("bodyA")=a, ^BG.RetentionTests("bodyB")=b
    // Same body shared with a recent header in a different completed session.
    do ..Header("BG.RetentionTests.Message",a,101,9,old)
    do ..Header("BG.RetentionTests.Message",a,102,9,recent)
    // An old terminal header in a session with a newer queued message of another class.
    do ..Header("BG.RetentionTests.Message",..Body("BG.RetentionTests.Message"),103,9,old)
    do ..Header("BG.RetentionTests.Other",b,103,2,recent)
    // Missing session cannot be assumed complete.
    do ..Header("BG.RetentionTests.Message",..Body("BG.RetentionTests.Message"),0,9,old)
    // A standalone complete header, including an equal numeric body ID in another class.
    do ..Header("BG.RetentionTests.Other",..Body("BG.RetentionTests.Other"),104,9,old)
    do ..Header("BG.RetentionTests.Protected",p,105,9,old)
    set ^BG.RetentionTests("seeded")=1
}

ClassMethod Body(class As %String) As %Integer
{
    set body=$classmethod(class,"%New"),body.Text="Synthetic retention verification fixture"
    set sc=body.%Save() $$$ThrowOnError(sc)
    return body.%Id()
}

ClassMethod Header(class As %String, body As %Integer, session As %Integer, status As %Integer, created As %String) As %Integer
{
    set h=##class(Ens.MessageHeader).%New()
    set h.MessageBodyClassName=class,h.MessageBodyId=body,h.SessionId=session,h.Status=status,h.TimeCreated=created,h.Type=1
    set sc=h.%Save() $$$ThrowOnError(sc)
    return h.%Id()
}
}
