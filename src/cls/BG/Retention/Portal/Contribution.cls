/// Namespace-scoped production message retention planning. Does not execute purge.
Class BG.Retention.Portal.Contribution Extends Portal.Ext.Contribution
{
Parameter ID = "io.github.bg-ak.portal.message-retention";
Parameter NAME = "Production Message Retention";
Parameter VERSION = "0.1.0";
Parameter APIVERSION As INTEGER = 2;
Parameter PUBLISHER = "Alexander Kolesov";
Parameter ORDER As INTEGER = 300;
Parameter REQUIRES = "BG_RetentionView,BG_RetentionEdit";

ClassMethod Contribute(slot As %String) As %DynamicArray
{
    return:slot="shell.nav" [{"id":"retention.planner","label":"Message retention","group":"Interoperability","icon":"pi pi-history","url":"BG.Retention.Portal.Page.cls","order":300,"resource":"BG_RetentionView"}]
    return:slot="page.home.widgets.dashboard" [{"id":"retention.summary","component":"BG.Retention.Portal.Summary","title":"Message retention","order":300,"resource":"BG_RetentionView"}]
    return []
}
}
