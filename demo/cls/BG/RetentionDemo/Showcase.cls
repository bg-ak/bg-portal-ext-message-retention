Class BG.RetentionDemo.Showcase Extends Banksia.Bloom.Component
{
Parameter PROPS = "ctx";
Property dataset As %DynamicObject [ InitialExpression = {{"rows":[],"asOfUTC":""}} ];
Property error As %String;
Property busy As %Boolean;
Property demoNamespace As %String [ InitialExpression = {$namespace} ];
Method %OnNew() As %Status
{
    try { do ##class(BG.Retention.Portal.Access).Check() set ..dataset=##class(BG.RetentionDemo.Dataset).Read() }
    catch ex { set ..error=$system.Status.GetErrorText(ex.AsStatus()) }
    return $$$OK
}
ClassMethod ReadDemo() As %String [ WebMethod ]
{
    try { do ##class(BG.Retention.Portal.Access).Check() return {"ok":true,"dataset":(##class(BG.RetentionDemo.Dataset).Read())}.%ToJSON() }
    catch ex { return {"ok":false,"error":($system.Status.GetErrorText(ex.AsStatus()))}.%ToJSON() }
}
ClientMethod refresh() [ Language = javascript ]
{
    this.busy=true; this.error='';
    try { const r=JSON.parse(await this.ReadDemo()); if (!r.ok) throw new Error(r.error); this.dataset=r.dataset; }
    catch (e) { this.error=e.message; }
    finally { this.busy=false; }
}
XData Template [ MimeType = text/vue ]
{
<div v-if="ctx === demoNamespace" class="flex flex-col gap-4">
  <p>Accounting documents, tow-truck GPS positions and towing status updates have different useful lifetimes.</p>
  <p class="text-sm text-gray-500">Synthetic message contents with actual IRIS headers. Results use the saved policies above. “Past retention” means age expiry only; nothing is deleted.</p>
  <p v-if="error" role="alert" class="text-red-600">{{ error }}</p>
  <DataTable :value="dataset.rows" dataKey="ID" size="small" class="text-sm">
    <template #empty>Seed the optional demo in an empty disposable namespace to see the messages.</template>
    <Column field="Category" header="Message type" />
    <Column field="Summary" header="Example message" />
    <Column field="Age" header="Age" style="white-space:nowrap" />
    <Column field="Retention" header="Keep for" />
    <Column header="Result"><template #body="{data}"><Tag :value="data.Result" :severity="data.Decision === 'past' ? 'warn' : data.Decision === 'never' ? 'info' : 'success'" /></template></Column>
  </DataTable>
  <div class="flex items-center gap-4"><PButton label="Refresh saved policies" icon="pi pi-refresh" text @click="refresh" :disabled="busy" /><span class="text-sm text-gray-500">Observed {{ dataset.asOfUTC }} UTC. Save a policy change, then refresh to compare.</span></div>
</div>
<p v-else>Select {{ demoNamespace }} to see this installation's synthetic demo messages.</p>
}
}
