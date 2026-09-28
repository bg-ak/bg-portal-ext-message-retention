/// Installation creates resources with no public permissions and assigns no roles.
/// Data and resources deliberately survive disable, retirement and package removal.
Class BG.Retention.Setup Extends %RegisteredObject
{
ClassMethod Install() As %Status
{
    new $namespace
    set $namespace = "%SYS"
    for name = "BG_RetentionView", "BG_RetentionEdit" {
        if '##class(Security.Resources).Exists(name) {
            set sc = ##class(Security.Resources).Create(name, "Production message retention " _ $select(name="BG_RetentionView":"analysis",1:"policy editing"), "")
            return:$$$ISERR(sc) sc
        }
    }
    return $$$OK
}
}
