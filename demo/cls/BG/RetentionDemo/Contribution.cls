/// Optional demonstration contribution, loaded only by demo/seed.sh.
Class BG.RetentionDemo.Contribution Extends Portal.Ext.Contribution
{
Parameter ID = "io.github.bg-ak.portal.message-retention.demo";
Parameter NAME = "Message Retention · synthetic examples";
Parameter VERSION = "0.2.0";
Parameter APIVERSION As INTEGER = 2;
Parameter PUBLISHER = "Alexander Kolesov";
Parameter REQUIRES = "BG_RetentionView";
ClassMethod Contribute(slot As %String) As %DynamicArray
{
    return:slot="page.retention.planner.widgets.examples" [{"id":"retention.demo.messages","component":"BG.RetentionDemo.Showcase","title":"Demo messages · a towing operation","resource":"BG_RetentionView","order":10}]
    return []
}
}
