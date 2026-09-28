/// IRIS metadata adapter. Reads headers only, in the requested namespace, as the caller.
/// No dependency on Portal, no elevated roles, no body opening and no purge operations.
Class BG.Retention.Source Extends %RegisteredObject
{
/// Report stored class metadata; a body need not derive from Ens.MessageBody.
ClassMethod ClassInfo(target As %String, bodyClass As %String) As %DynamicObject
{
    do ##class(BG.Retention.Service).Require()
    set target = ##class(BG.Retention.Service).Target(target)
    new $namespace
    set $namespace = target
    set info = {"exists": false, "persistent": false, "purgeProtected": false}
    if ##class(%Dictionary.CompiledClass).%ExistsId(bodyClass) {
        do info.%Set("exists", 1, "boolean")
        do info.%Set("persistent", $classmethod(bodyClass, "%Extends", "%Persistent"), "boolean")
        do info.%Set("purgeProtected", $parameter(bodyClass, "ENSPURGE")=0, "boolean")
    }
    return info
}

/// A bounded inventory of recently created headers, not a complete class catalogue.
ClassMethod Inventory(target As %String, limit As %Integer = 1000) As %DynamicObject
{
    do ##class(BG.Retention.Service).Require()
    set target = ##class(BG.Retention.Service).Target(target)
    if (limit<1) || (limit>1000) { throw ##class(%Exception.General).%New("Inventory limit must be from 1 to 1000") }
    new $namespace
    set $namespace = target
    set stmt = ##class(%SQL.Statement).%New()
    set sc = stmt.%Prepare("SELECT TOP ? MessageBodyClassName FROM Ens.MessageHeader ORDER BY ID DESC", 1)
    $$$ThrowOnError(sc)
    set rs = stmt.%Execute(limit+1), count = 0, classes = []
    while rs.%Next() {
        set count = count+1
        quit:count>limit
        set name = rs.%Get("MessageBodyClassName")
        if (name'="") && '$data(seen(name)) { set seen(name)=1 do classes.%Push(name) }
    }
    if rs.%SQLCODE<0 { throw ##class(%Exception.General).%New(rs.%Message) }
    do rs.%Close()
    return {"classes": (classes), "headersInspected": ($select(count>limit:limit,1:count)), "truncated": (count>limit)}
}

/// Collect age-matched headers and independent caution flags. These are NOT a purge plan.
/// The correlated checks include headers outside the age window and of other types.
/// TOP bounds returned candidates, not physical SQL work; use on-demand off-peak.
ClassMethod Scan(target As %String, bodyClass As %String, cutoff As %String, limit As %Integer) As %DynamicObject
{
    do ##class(BG.Retention.Service).Require()
    set target = ##class(BG.Retention.Service).Target(target)
    if (limit<1) || (limit>1000) { throw ##class(%Exception.General).%New("Preview limit must be from 1 to 1000") }
    new $namespace
    set $namespace = target
    set stmt = ##class(%SQL.Statement).%New()
    set sql = "SELECT TOP ? h.ID, h.MessageBodyId, h.SessionId, h.TimeCreated, h.Status, " _
        "CASE WHEN h.SessionId IS NULL OR h.SessionId=0 OR h.Status IS NULL OR h.Status NOT IN (4,7,8,9) " _
        "OR EXISTS (SELECT 1 FROM Ens.MessageHeader s WHERE s.SessionId=h.SessionId AND (s.Status IS NULL OR s.Status NOT IN (4,7,8,9))) " _
        "THEN 1 ELSE 0 END AS SessionBlocked, " _
        "CASE WHEN EXISTS (SELECT 1 FROM Ens.MessageHeader b WHERE b.MessageBodyClassName=h.MessageBodyClassName AND b.MessageBodyId=h.MessageBodyId AND b.ID<>h.ID) " _
        "THEN 1 ELSE 0 END AS SharedBody " _
        "FROM Ens.MessageHeader h WHERE h.MessageBodyClassName=? AND h.TimeCreated<? ORDER BY h.TimeCreated, h.ID"
    set sc = stmt.%Prepare(sql, 1)
    $$$ThrowOnError(sc)
    set rs = stmt.%Execute(limit+1, bodyClass, cutoff)
    set rows = [], count = 0, blocked = 0, shared = 0, missing = 0
    while rs.%Next() {
        set count = count+1
        quit:count>limit
        set sessionBlocked = +rs.%Get("SessionBlocked"), sharedBody = +rs.%Get("SharedBody"), noBody = rs.%Get("MessageBodyId")=""
        set blocked = blocked+sessionBlocked, shared = shared+sharedBody, missing = missing+noBody
        do rows.%Push({"ID": (rs.%Get("ID")), "SessionId": (rs.%Get("SessionId")), "CreatedUTC": (rs.%Get("TimeCreated")), "Status": (rs.%Get("Status")), "SessionBlocked": (sessionBlocked), "SharedBody": (sharedBody), "MissingBodyId": (noBody)})
    }
    if rs.%SQLCODE<0 { throw ##class(%Exception.General).%New(rs.%Message) }
    do rs.%Close()
    return {"rows": (rows), "matched": (rows.%Size()), "truncated": (count>limit), "sessionBlocked": (blocked), "sharedBody": (shared), "missingBodyId": (missing)}
}
}
