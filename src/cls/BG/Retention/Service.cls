/// UI-independent policy application service. All public entry points authorize the caller.
Class BG.Retention.Service Extends %RegisteredObject
{
ClassMethod Require(edit As %Boolean = 0)
{
    if '$system.Security.Check("BG_RetentionView", "USE") {
        throw ##class(%Exception.General).%New("BG_RetentionView:USE is required")
    }
    if edit && '$system.Security.Check("BG_RetentionEdit", "USE") {
        throw ##class(%Exception.General).%New("BG_RetentionEdit:USE is required")
    }
}

ClassMethod Target(target As %String) As %String
{
    set target = $zconvert($zstrip(target,"<>W"), "U")
    if (target="") || ($length(target)>64) || (target="%SYS") || '##class(%SYS.Namespace).Exists(target) {
        throw ##class(%Exception.General).%New("Choose an existing application namespace")
    }
    return target
}

ClassMethod Validate(bodyClass As %String, mode As %String, amount As %String)
{
    if (bodyClass="") || ($length(bodyClass)>220) {
        throw ##class(%Exception.General).%New("An exact message body class is required")
    }
    if (mode'="days") && (mode'="hours") && (mode'="never") {
        throw ##class(%Exception.General).%New("Retention must be hours, days or never")
    }
    if mode'="never" {
        set max=$select(mode="hours":876000,1:36500)
        if (amount'?1.N) || (+amount<1) || (+amount>max) {
            throw ##class(%Exception.General).%New("Retention must be an integer from 1 to "_max_" "_mode)
        }
    }
}

/// Elapsed time in UTC; the default retains the original two-argument day API.
ClassMethod Cutoff(asOf As %String, amount As %Integer, unit As %String = "days") As %String
{
    do ..Validate("cutoff",unit,amount)
    if unit="never" { return "" }
    set utc = $zdatetimeh(asOf, 3)
    set seconds=($piece(utc,",")*86400)+$piece(utc,",",2)-(amount*$select(unit="hours":3600,1:86400))
    return $zdatetime((seconds\86400)_","_(seconds#86400),3,1)
}

ClassMethod Rules(target As %String) As %DynamicArray
{
    do ..Require()
    set target = ..Target(target), rows = []
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT BodyClass, Mode, KeepDays, KeepHours, DisplayName, Reason, Revision, UpdatedAt, UpdatedBy FROM BG_Retention.Rule WHERE TargetNamespace=? ORDER BY BodyClass", target)
    while rs.%Next() {
        do rows.%Push({"BodyClass": (rs.%Get("BodyClass")), "Mode": (rs.%Get("Mode")), "KeepDays": (rs.%Get("KeepDays")), "KeepHours": (rs.%Get("KeepHours")), "KeepFor": ($select(rs.%Get("Mode")="hours":rs.%Get("KeepHours"),1:rs.%Get("KeepDays"))), "DisplayName": (rs.%Get("DisplayName")), "Reason": (rs.%Get("Reason")), "Revision": (rs.%Get("Revision")), "UpdatedAt": (rs.%Get("UpdatedAt")), "UpdatedBy": (rs.%Get("UpdatedBy"))})
    }
    if rs.%SQLCODE<0 { throw ##class(%Exception.General).%New(rs.%Message) }
    return rows
}

/// Observed types plus every saved policy, including types with no recent headers.
/// Discovery is bounded; an unconfigured type has no implicit retention default.
ClassMethod Catalog(target As %String, limit As %Integer = 1000) As %DynamicObject
{
    do ..Require()
    set target=..Target(target), inventory=##class(BG.Retention.Source).Inventory(target,limit)
    set rules=..Rules(target), rows=[]
    for i=0:1:inventory.classes.%Size()-1 {
        set name=inventory.classes.%Get(i)
        set types(name)={"BodyClass":(name),"Mode":"","KeepFor":"","DisplayName":"","Reason":"","Revision":0}
    }
    for i=0:1:rules.%Size()-1 {
        set rule=rules.%Get(i),types(rule.BodyClass)=rule
    }
    set name=""
    for {
        set name=$order(types(name))
        quit:name=""
        do rows.%Push(types(name))
    }
    return {"types":(rows),"headersInspected":(inventory.headersInspected),"truncated":(inventory.truncated)}
}

/// expectedRevision=0 creates only; otherwise an atomic compare-and-update prevents stale edits.
/// Policy and its outcome audit commit together. A failed audit rolls the policy back.
ClassMethod Save(target As %String, bodyClass As %String, mode As %String, amount As %String, expectedRevision As %String, displayName As %String = "", reason As %String = "") As %Status
{
    set level = $tlevel
    try {
        do ..Require(1)
        set target = ..Target(target)
        do ..Validate(bodyClass, mode, amount)
        if ($length(displayName)>120)||($length(reason)>300) { throw ##class(%Exception.General).%New("Name is limited to 120 characters and reason to 300") }
        if expectedRevision'?1.N { throw ##class(%Exception.General).%New("Invalid policy revision") }
        set info = ##class(BG.Retention.Source).ClassInfo(target, bodyClass)
        if 'info.persistent { throw ##class(%Exception.General).%New("Body class must exist and be persistent in the target namespace") }
        set days=$select(mode="days":+amount,1:""),hours=$select(mode="hours":+amount,1:""),now=$zdatetime($ztimestamp,3,1)
        tstart
        if expectedRevision=0 {
            set rs = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO BG_Retention.Rule (TargetNamespace,BodyClass,Mode,KeepDays,KeepHours,DisplayName,Reason,Revision,UpdatedAt,UpdatedBy) VALUES (?,?,?,?,?,?,?,1,?,?)", target, bodyClass, mode, days, hours, displayName, reason, now, $username)
        } else {
            set rs = ##class(%SQL.Statement).%ExecDirect(, "UPDATE BG_Retention.Rule SET Mode=?,KeepDays=?,KeepHours=?,DisplayName=?,Reason=?,Revision=Revision+1,UpdatedAt=?,UpdatedBy=? WHERE TargetNamespace=? AND BodyClass=? AND Revision=?", mode, days, hours, displayName, reason, now, $username, target, bodyClass, expectedRevision)
        }
        if (rs.%SQLCODE<0) || (rs.%ROWCOUNT'=1) {
            throw ##class(%Exception.General).%New("Policy was not saved. Reload before editing; it may have changed in another session. "_rs.%Message)
        }
        do ..Record("policy.saved", target, bodyClass, {"mode": (mode), "keepDays": (days), "keepHours": (hours), "displayName": (displayName), "reason": (reason), "previousRevision": (+expectedRevision), "revision": (expectedRevision+1)})
        tcommit
        return $$$OK
    } catch ex {
        if $tlevel>level { trollback 1 }
        return ex.AsStatus()
    }
}

ClassMethod Preview(target As %String, bodyClass As %String, mode As %String, amount As %String, limit As %String = 500) As %DynamicObject
{
    do ..Require()
    set target = ..Target(target)
    do ..Validate(bodyClass, mode, amount)
    if (limit'?1.N) || (+limit<1) || (+limit>1000) { throw ##class(%Exception.General).%New("Preview limit must be from 1 to 1000") }
    set now = $zdatetime($ztimestamp,3,1), info = ##class(BG.Retention.Source).ClassInfo(target, bodyClass)
    set result = {"rows": [], "matched": 0, "truncated": false, "sessionBlocked": 0, "sharedBody": 0, "missingBodyId": 0}
    set cutoff = ""
    if mode'="never" {
        set cutoff = ..Cutoff(now, amount, mode)
        set result = ##class(BG.Retention.Source).Scan(target, bodyClass, cutoff, limit)
    }
    do result.%Set("namespace", target)
    do result.%Set("bodyClass", bodyClass)
    do result.%Set("mode", mode)
    do result.%Set("keepDays", $select(mode="days":+amount,1:""))
    do result.%Set("keepHours", $select(mode="hours":+amount,1:""))
    do result.%Set("keepFor", $select(mode="never":"",1:+amount))
    do result.%Set("asOfUTC", now)
    do result.%Set("cutoffUTC", cutoff)
    do result.%Set("classInfo", info)
    do result.%Set("executable", 0, "boolean")
    do ..Record("preview.completed", target, bodyClass, {"mode": (mode), "keepDays": (result.keepDays), "keepHours": (result.keepHours), "cutoffUTC": (cutoff), "limit": (+limit), "matched": (result.matched), "truncated": (result.truncated), "sessionBlocked": (result.sessionBlocked), "sharedBody": (result.sharedBody), "purgeProtected": (info.purgeProtected)})
    return result
}

ClassMethod History(target As %String) As %DynamicArray
{
    do ..Require()
    set target = ..Target(target), rows = []
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 50 AtUTC,Actor,Operation,BodyClass,Details FROM BG_Retention.Audit WHERE TargetNamespace=? ORDER BY ID DESC", target)
    while rs.%Next() {
        do rows.%Push({"AtUTC": (rs.%Get("AtUTC")), "Actor": (rs.%Get("Actor")), "Operation": (rs.%Get("Operation")), "BodyClass": (rs.%Get("BodyClass")), "Details": (rs.%Get("Details"))})
    }
    if rs.%SQLCODE<0 { throw ##class(%Exception.General).%New(rs.%Message) }
    return rows
}

ClassMethod Record(operation As %String, target As %String, bodyClass As %String, details As %DynamicObject)
{
    do ..Require()
    set entry = ##class(BG.Retention.Audit).%New()
    set entry.AtUTC = $zdatetime($ztimestamp,3,1), entry.Actor = $username, entry.Operation = operation
    set entry.TargetNamespace = target, entry.BodyClass = bodyClass, entry.Details = details.%ToJSON()
    set sc = entry.%Save()
    $$$ThrowOnError(sc)
}
}
