/// Native executable integration tests; run only on the disposable instance described in README.
Class BG.RetentionTests.Runner Extends %RegisteredObject
{
ClassMethod Assert(ok As %Boolean, message As %String)
{
    if 'ok { throw ##class(%Exception.General).%New("FAILED: "_message) }
    set ^BG.RetentionTests("passed")=$get(^BG.RetentionTests("passed"))+1
    write "PASS: ",message,!
}

ClassMethod Run() As %Status
{
    set level=$tlevel
    try {
        if $get(^BG.RetentionTests("allowFixtures"))'=1 { throw ##class(%Exception.General).%New("Use disposable-instance test instructions") }
        set auditBefore=..AuditCount()
        tstart
        set ^BG.RetentionTests("passed")=0
        do ##class(BG.RetentionTests.Fixture).Seed()
        set target=$namespace, class="BG.RetentionTests.Message"
        do ..Assert(##class(BG.Retention.Service).Cutoff("2026-09-28 12:34:56",1)="2026-09-27 12:34:56","UTC elapsed-day cutoff")
        do ..Assert(##class(BG.Retention.Service).Cutoff("2024-03-01 00:00:00",1)="2024-02-29 00:00:00","Leap-day boundary")
        set sc=##class(BG.Retention.Service).Save(target,class,"days",1,0)
        do ..Assert($$$ISOK(sc),"Create 1-day rule for a plain persistent message class")
        set sc=##class(BG.Retention.Service).Save(target,class,"days",50,1)
        do ..Assert($$$ISOK(sc),"Update to 50 days")
        set sc=##class(BG.Retention.Service).Save(target,class,"days",365,2)
        do ..Assert($$$ISOK(sc),"Update to 365 days")
        set sc=##class(BG.Retention.Service).Save(target,class,"never","",3)
        do ..Assert($$$ISOK(sc),"Explicit never policy")
        set sc=##class(BG.Retention.Service).Save(target,class,"days",1,2)
        do ..Assert($$$ISERR(sc),"Stale edit rejected")
        set sc=##class(BG.Retention.Service).Save(target,class,"days",1,0)
        do ..Assert($$$ISERR(sc),"Duplicate create rejected")
        for days=0,-1,1.5,"abc",36501 {
            set sc=##class(BG.Retention.Service).Save(target,class,"days",days,4)
            do ..Assert($$$ISERR(sc),"Reject invalid days "_days)
        }
        set rules=##class(BG.Retention.Service).Rules(target)
        do ..Assert(rules.%Size()=1,"No duplicate rules")
        do ..Assert(rules.%Get(0).Mode="never","Failed edits preserve policy")
        do ..Assert(rules.%Get(0).Revision=4,"Failed edits do not advance revision")
        set p=##class(BG.Retention.Service).Preview(target,class,"days",50)
        do ..Assert(p.matched=3,"Exact class and age filter")
        do ..Assert(p.sessionBlocked=2,"Other-type newer incomplete session and unknown session blocked")
        do ..Assert(p.sharedBody=1,"Shared body referenced outside age window detected")
        do ..Assert('p.executable,"Preview never claims executable deletion")
        set p=##class(BG.Retention.Service).Preview(target,class,"days",50,1)
        do ..Assert(p.truncated && (p.matched=1),"Bounded preview reports truncation")
        set p=##class(BG.Retention.Service).Preview(target,class,"days",50,3)
        do ..Assert('p.truncated && (p.matched=3),"Exact limit is not falsely truncated")
        set p=##class(BG.Retention.Service).Preview(target,class,"never","")
        do ..Assert((p.matched=0)&&(p.cutoffUTC=""),"Never performs no age scan")
        set p=##class(BG.Retention.Service).Preview(target,"BG.RetentionTests.Protected","days",1)
        do ..Assert(p.classInfo.purgeProtected && (p.matched=1),"ENSPURGE=0 remains visible as a body-only restriction")
        set p=##class(BG.Retention.Service).Preview(target,"BG.RetentionTests.Other","days",1)
        do ..Assert((p.matched=1)&&('p.sharedBody),"Body identity includes class, not numeric ID alone")
        // Strict cutoff, including a message created at exactly the boundary.
        set boundary=##class(BG.Retention.Service).Cutoff($zdatetime($ztimestamp,3,1),200)
        do ##class(BG.RetentionTests.Fixture).Header(class,##class(BG.RetentionTests.Fixture).Body(class),106,9,boundary)
        set p=##class(BG.Retention.Source).Scan(target,class,boundary,500)
        do ..Assert(p.matched=0,"Exclusive cutoff does not include equality")
        // Missing class and SQL metacharacters cannot broaden selection.
        set p=##class(BG.Retention.Service).Preview(target,"Missing.Class' OR 1=1 --","days",1)
        do ..Assert((p.matched=0)&&('p.classInfo.exists),"Class input is bound, never SQL text")
        set inv=##class(BG.Retention.Source).Inventory(target,1)
        do ..Assert(inv.truncated && (inv.headersInspected=1),"Inventory describes its limited scope")
        set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Ens.MessageHeader")
        do rs.%Next()
        do ..Assert(rs.%Get("N")=8,"Previews leave every header intact")
        do ..Assert(##class(BG.RetentionTests.Message).%ExistsId(^BG.RetentionTests("bodyA")),"Previews leave bodies intact")
        do ..Assert(..AuditCount()=auditBefore+11,"Committed policy saves and completed previews are audited")
        set contribution="BG.Retention.Portal.Contribution"
        set sc=##class(Portal.Ext.Registry).SetEnabled(contribution,0)
        $$$ThrowOnError(sc)
        set denied=0
        try { do ##class(BG.Retention.Portal.Access).Check() } catch ex { set denied=1 }
        do ..Assert(denied,"Disabled extension blocks direct page API")
        set sc=##class(Portal.Ext.Registry).SetEnabled(contribution,1)
        $$$ThrowOnError(sc)
        set sc=##class(Portal.Ext.Registry).Uninstall(contribution)
        $$$ThrowOnError(sc)
        set denied=0
        try { do ##class(BG.Retention.Portal.Access).Check() } catch ex { set denied=1 }
        do ..Assert(denied,"Retired extension blocks direct page API")
        set sc=##class(Portal.Ext.Registry).Reinstall(contribution)
        $$$ThrowOnError(sc)
        do ..Assert(##class(BG.Retention.Service).Rules(target).%Size()=1,"Lifecycle preserves policy data")
        set total=^BG.RetentionTests("passed")
        trollback 1
        write "RETENTION TESTS PASSED: ",total,!
        return $$$OK
    } catch ex {
        if $tlevel>level { trollback 1 }
        write $system.Status.GetErrorText(ex.AsStatus()),!
        return ex.AsStatus()
    }
}

ClassMethod AuditCount() As %Integer
{
    set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM BG_Retention.Audit WHERE TargetNamespace=?",$namespace)
    if rs.%SQLCODE<0 { throw ##class(%Exception.General).%New(rs.%Message) }
    do rs.%Next()
    return rs.%Get("N")
}
}
