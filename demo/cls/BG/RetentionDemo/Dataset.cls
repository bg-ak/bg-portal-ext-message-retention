/// Reads only explicitly tracked, whitelisted synthetic demo bodies.
/// Real production analysis in BG.Retention.Source remains header-only.
Class BG.RetentionDemo.Dataset Extends %RegisteredObject
{
ClassMethod Read() As %DynamicObject
{
    do ##class(BG.Retention.Service).Require()
    set rows=[],now=$zdatetime($ztimestamp,3,1)
    if $get(^BG.RetentionDemo("version"))'="0.2.0" { return {"rows":(rows),"asOfUTC":(now)} }
    set rules=##class(BG.Retention.Service).Rules($namespace)
    for i=0:1:rules.%Size()-1 { set rule=rules.%Get(i),byClass(rule.BodyClass)=rule }
    set id="",count=0
    for {
        set id=$order(^BG.RetentionDemo("headers",id)) quit:id=""
        set count=count+1 quit:count>100
        set h=##class(Ens.MessageHeader).%OpenId(id)
        continue:'$isobject(h)
        set class=h.MessageBodyClassName
        continue:'$listfind($lb("BG.RetentionDemo.FinancialDocument","BG.RetentionDemo.TowTruckLocation","BG.RetentionDemo.RecoveryStatus"),class)
        set body=$classmethod(class,"%OpenId",h.MessageBodyId)
        continue:'$isobject(body)
        set text=""
        if class="BG.RetentionDemo.FinancialDocument" { set text=body.DocumentNumber_" · "_body.EntryType_" · "_body.Amount_" "_body.Currency }
        if class="BG.RetentionDemo.TowTruckLocation" { set text=body.VehicleId_" · "_body.Latitude_", "_body.Longitude }
        if class="BG.RetentionDemo.RecoveryStatus" { set text=body.JobReference_" · "_body.StatusLabel }
        set name=class,retention="No policy",decision="unconfigured",label="No policy",cutoff=""
        if $data(byClass(class)) {
            set rule=byClass(class),name=$select(rule.DisplayName="":class,1:rule.DisplayName)
            if rule.Mode="never" { set retention="Keep indefinitely",decision="never",label="Keep indefinitely" }
            else {
                set retention=rule.KeepFor_" "_$select(rule.KeepFor=1:$extract(rule.Mode,1,$length(rule.Mode)-1),1:rule.Mode)
                set cutoff=##class(BG.Retention.Service).Cutoff(now,rule.KeepFor,rule.Mode)
                set decision=$select(cutoff]h.TimeCreated:"past",1:"within")
                set label=$select(decision="past":"Past retention",1:"Within retention")
            }
        }
        set stamp=$zdatetimeh(h.TimeCreated,3),current=$zdatetimeh(now,3)
        set age=($piece(current,",")-$piece(stamp,","))*86400+$piece(current,",",2)-$piece(stamp,",",2)
        set ageLabel=$select(age<3600:(age\60)_" min",age<86400:(age\3600)_" hours",1:(age\86400)_" days")
        do rows.%Push({"ID":(id),"BodyClass":(class),"Category":(name),"Summary":(text),"CreatedUTC":(h.TimeCreated),"Age":(ageLabel),"Retention":(retention),"Decision":(decision),"Result":(label)})
    }
    return {"rows":(rows),"asOfUTC":(now)}
}
}
