/// Native shell and PrimeVue components, emitted by Bloom; no frontend build.
Class BG.Retention.Portal.Page Extends Portal.Page
{
Parameter RESOURCE = "BG_RetentionView";
Parameter PAGEID = "retention.planner";
Parameter TITLE = "Production Message Retention";

Property target As %String [ InitialExpression = {$namespace} ];
Property loadedNamespace As %String;
Property saved As %DynamicArray [ InitialExpression = {[]} ];
Property types As %DynamicArray [ InitialExpression = {[]} ];
Property inventory As %DynamicObject [ InitialExpression = {{"headersInspected":0,"truncated":false}} ];
Property history As %DynamicArray [ InitialExpression = {[]} ];
Property newClass As %String;
Property modes As %DynamicArray [ InitialExpression = {[{"label":"Hours","value":"hours"},{"label":"Days","value":"days"},{"label":"Never delete","value":"never"}]} ];
Property preview As %DynamicObject [ InitialExpression = {{}} ];
Property canEdit As %Boolean [ InitialExpression = 0 ];
Property busy As %Boolean [ InitialExpression = 0 ];
Property error As %String;
Property notice As %String;

Method %OnNew() As %Status
{
    try {
        do ##class(BG.Retention.Portal.Access).Check()
        set ..loadedNamespace = ##class(BG.Retention.Service).Target(..target)
        set ..inventory = ##class(BG.Retention.Service).Catalog(..loadedNamespace), ..types = ..inventory.types, ..saved = ##class(BG.Retention.Service).Rules(..loadedNamespace)
        set ..history = ##class(BG.Retention.Service).History(..loadedNamespace)
        set ..canEdit = $system.Security.Check("BG_RetentionEdit", "USE")
    } catch ex { set ..loadedNamespace = "", ..error = $system.Status.GetErrorText(ex.AsStatus()) }
    return $$$OK
}

ClassMethod OnPreHTTP() As %Boolean
{
    set ok = ##super()
    try { do ##class(BG.Retention.Portal.Access).Check() }
    catch ex { set %response.ServerSideRedirect = "Portal.Forbidden.cls" }
    return ok
}

ClassMethod OnPreHyperEvent(class As %String, method As %String) As %Status
{
    set sc = ##super(class, method)
    return:$$$ISERR(sc) sc
    try { do ##class(BG.Retention.Portal.Access).Check() }
    catch ex { return ex.AsStatus() }
    return $$$OK
}

/// Keep the original day-only WebMethod payload usable after an upgrade.
ClassMethod Amount(obj As %DynamicObject) As %String
{
    if obj.%IsDefined("KeepFor") { return obj.%Get("KeepFor") }
    return $select(obj.Mode="hours":obj.%Get("KeepHours"),1:obj.%Get("KeepDays"))
}

ClassMethod ReadView(target As %String) As %String [ WebMethod ]
{
    try {
        do ##class(BG.Retention.Portal.Access).Check()
        set target = ##class(BG.Retention.Service).Target(target)
        return {"ok":true,"namespace":(target),"catalog":(##class(BG.Retention.Service).Catalog(target)),"rules":(##class(BG.Retention.Service).Rules(target)),"history":(##class(BG.Retention.Service).History(target)),"canEdit":($system.Security.Check("BG_RetentionEdit","USE"))}.%ToJSON()
    } catch ex { return ..ActionResult(ex.AsStatus()) }
}

ClassMethod Discover(target As %String) As %String [ WebMethod ]
{
    try {
        do ##class(BG.Retention.Portal.Access).Check()
        return {"ok":true,"inventory":(##class(BG.Retention.Source).Inventory(target))}.%ToJSON()
    } catch ex { return ..ActionResult(ex.AsStatus()) }
}

ClassMethod SaveRule(target As %String, json As %String) As %String [ WebMethod ]
{
    try {
        do ##class(BG.Retention.Portal.Access).Check()
        set obj = {}.%FromJSON(json)
        return ..ActionResult(##class(BG.Retention.Service).Save(target, obj.BodyClass, obj.Mode, ..Amount(obj), obj.Revision, obj.%Get("DisplayName"), obj.%Get("Reason")))
    } catch ex { return ..ActionResult(ex.AsStatus()) }
}

ClassMethod Analyze(target As %String, json As %String) As %String [ WebMethod ]
{
    try {
        do ##class(BG.Retention.Portal.Access).Check()
        set obj = {}.%FromJSON(json)
        return {"ok":true,"preview":(##class(BG.Retention.Service).Preview(target,obj.BodyClass,obj.Mode,..Amount(obj)))}.%ToJSON()
    } catch ex { return ..ActionResult(ex.AsStatus()) }
}

ClientMethod changed(row) [ Language = javascript ]
{
    row.Dirty = true; row.Preview = null; row.Error = ''; this.preview = {}; this.notice = '';
}

ClientMethod undo(row) [ Language = javascript ]
{
    const saved = this.saved.find(x => x.BodyClass === row.BodyClass);
    Object.assign(row, saved || { Mode: '', KeepFor: '', DisplayName: '', Reason: '', Revision: 0 }, { Dirty: false, Preview: null, Error: '' });
    this.preview = {}; this.notice = '';
}

ClientMethod load() [ Language = javascript ]
{
    this.busy = true; this.error = ''; this.notice = ''; this.preview = {};
    try {
        const r = JSON.parse(await this.ReadView(this.target));
        if (!r.ok) throw new Error(r.error);
        this.loadedNamespace = r.namespace; this.target = r.namespace;
        this.types = r.catalog.types; this.inventory = r.catalog; this.saved = r.rules;
        this.history = r.history; this.canEdit = !!r.canEdit; this.newClass = '';
    } catch (e) { this.error = e.message; this.loadedNamespace = ''; this.types = []; this.history = []; }
    finally { this.busy = false; }
}

ClientMethod addType() [ Language = javascript ]
{
    const name = this.newClass.trim();
    if (!name) return;
    if (this.types.some(r => r.BodyClass === name)) { this.notice = 'This type is already in the list.'; return; }
    this.types.push({ BodyClass: name, Mode: '', KeepFor: '', DisplayName: '', Reason: '', Revision: 0, Dirty: false });
    this.newClass = ''; this.notice = 'Choose a retention period for ' + name + '. The class is validated when you save.';
}

ClientMethod save(row) [ Language = javascript ]
{
    this.busy = true; row.Error = ''; this.error = ''; this.notice = '';
    try {
        const r = JSON.parse(await this.SaveRule(this.loadedNamespace, JSON.stringify(row)));
        if (!r.ok) throw new Error(r.error);
        const view = JSON.parse(await this.ReadView(this.loadedNamespace));
        if (!view.ok) throw new Error('Policy saved, but reload failed: ' + view.error);
        const saved = view.rules.find(x => x.BodyClass === row.BodyClass);
        Object.assign(row, saved, { Dirty: false });
        this.saved = this.saved.filter(x => x.BodyClass !== row.BodyClass).concat([saved]);
        this.history = view.history;
        this.notice = 'Saved retention for ' + (row.DisplayName || row.BodyClass) + '. No cleanup was run.';
    } catch (e) { row.Error = e.message; }
    finally { this.busy = false; }
}

ClientMethod runPreview(row) [ Language = javascript ]
{
    this.busy = true; row.Error = ''; this.error = ''; this.notice = ''; this.preview = {};
    try {
        const r = JSON.parse(await this.Analyze(this.loadedNamespace, JSON.stringify(row)));
        if (!r.ok) throw new Error(r.error);
        row.Preview = r.preview; this.preview = r.preview;
        const view = JSON.parse(await this.ReadView(this.loadedNamespace));
        if (view.ok) this.history = view.history;
    } catch (e) { row.Error = e.message; }
    finally { this.busy = false; }
}

XData Template [ MimeType = text/vue ]
{
<div class="flex flex-col gap-4">
  <div><h1 class="text-2xl font-semibold">Production Message Retention</h1>
    <p class="text-sm text-gray-500 mt-1">Choose how long each kind of production message should be kept · <a href="https://github.com/bg-ak/bg-portal-ext-message-retention" class="text-blue-600 hover:underline">Extension source and installation</a></p></div>
  <p class="text-sm text-gray-500">Configure a retention rule for each type below. Preview only: cleanup is not implemented, and existing IRIS purge jobs are unchanged.</p>
  <div class="flex items-center gap-4">
    <label for="retention-namespace">Namespace</label>
    <InputText id="retention-namespace" v-model="target" :disabled="busy || types.some(r => r.Dirty)" @keyup.enter="load" />
    <PButton label="Reload types" icon="pi pi-refresh" @click="load" :disabled="busy || types.some(r => r.Dirty)" />
    <span v-if="types.some(r => r.Dirty)" class="text-sm">Save or undo row changes before reloading.</span>
  </div>
  <p v-if="error" role="alert" class="text-red-600">{{ error }}</p>
  <p v-if="notice" role="status">{{ notice }}</p>
  <template v-if="loadedNamespace">
    <Card><template #title>Message types · {{ loadedNamespace }}</template><template #content>
      <p class="text-sm text-gray-500 mb-4">Set how long to keep each type, then save its row. Preview checks the value currently shown, even before saving.</p>
      <DataTable :value="types" dataKey="BodyClass" :paginator="types.length > 10" :rows="10" size="small">
        <template #empty>No message types found. Enter an exact message body class below.</template>
        <Column header="Message type" style="min-width:240px"><template #body="{data}">
          <strong>{{ data.DisplayName || data.BodyClass }}</strong>
          <div v-if="data.DisplayName" class="text-xs text-gray-500" style="overflow-wrap:anywhere">{{ data.BodyClass }}</div>
          <div v-if="data.Reason" class="text-xs text-gray-500 mt-1">{{ data.Reason }}</div>
          <details v-if="canEdit" class="text-xs mt-1"><summary>Label / reason</summary>
            <InputText v-model="data.DisplayName" :aria-label="data.BodyClass + ' display name'" placeholder="Optional display name" maxlength="120" :disabled="busy" @update:modelValue="changed(data)" class="w-full mt-1" />
            <InputText v-model="data.Reason" :aria-label="data.BodyClass + ' reason'" placeholder="Why keep it this long?" maxlength="300" :disabled="busy" @update:modelValue="changed(data)" class="w-full mt-1" />
          </details>
        </template></Column>
        <Column header="Keep for" style="min-width:235px"><template #body="{data}">
          <div class="flex items-center gap-2">
            <InputText v-if="data.Mode === 'hours' || data.Mode === 'days'" v-model="data.KeepFor" :aria-label="data.BodyClass + ' retention amount'" type="number" min="1" :max="data.Mode === 'hours' ? 876000 : 36500" style="width:85px" :disabled="busy || !canEdit" @update:modelValue="changed(data)" />
            <Select v-model="data.Mode" :options="modes" optionLabel="label" optionValue="value" placeholder="Choose retention" :aria-label="data.BodyClass + ' retention unit'" :disabled="busy || !canEdit" @update:modelValue="changed(data)" />
          </div>
          <span class="text-xs text-gray-500">{{ data.Dirty ? 'Unsaved change' : data.Revision ? 'Saved rule' : 'No rule configured' }}</span>
        </template></Column>
        <Column header="Past retention" style="min-width:135px"><template #body="{data}">
          <span v-if="!data.Mode" class="text-sm text-gray-500">Choose a rule</span>
          <Tag v-else-if="data.Mode === 'never'" value="Never expires" severity="info" />
          <span v-else-if="data.Preview"><strong>{{ data.Preview.truncated ? 'At least ' : '' }}{{ data.Preview.matched }}</strong> headers<div class="text-xs text-gray-500">At {{ data.Preview.asOfUTC }} UTC</div></span>
          <span v-else class="text-sm text-gray-500">Not checked</span>
        </template></Column>
        <Column header="Actions" style="min-width:170px"><template #body="{data}">
          <div class="flex gap-2">
            <PButton v-if="canEdit" label="Save" icon="pi pi-save" size="small" @click="save(data)" :disabled="busy || !data.Mode || !data.Dirty" :aria-label="'Save ' + data.BodyClass" />
            <PButton label="Preview" text size="small" @click="runPreview(data)" :disabled="busy || !data.Mode" :aria-label="'Preview ' + data.BodyClass" />
          </div>
          <PButton v-if="data.Dirty" label="Undo" text size="small" @click="undo(data)" :disabled="busy" :aria-label="'Undo ' + data.BodyClass" />
          <p v-if="data.Error" role="alert" class="text-sm text-red-600">{{ data.Error }}</p>
        </template></Column>
      </DataTable>
      <p class="text-xs text-gray-500 mt-4">Found in {{ inventory.headersInspected }} recent headers, plus all saved rules. {{ inventory.truncated ? 'Discovery is partial: older message types may be missing.' : 'All current headers were inspected.' }} Counts are headers older than the selected period, not confirmed safe deletions.</p>
      <details v-if="canEdit" class="text-sm mt-4"><summary>Type missing? Add an exact body class</summary>
        <div class="flex gap-2 mt-2"><InputText v-model="newClass" aria-label="Additional message body class" placeholder="MyApp.Message" :disabled="busy" @keyup.enter="addType" /><PButton label="Add type" @click="addType" :disabled="busy || !newClass.trim()" /></div>
      </details>
    </template></Card>
    <Card v-if="preview.asOfUTC"><template #title>Preview details · {{ preview.namespace }} · {{ preview.bodyClass }}</template><template #content>
      <p>Observed at {{ preview.asOfUTC }} UTC. {{ preview.mode === 'never' ? 'No age expiry; no header scan was needed.' : 'Age cutoff: ' + preview.cutoffUTC + ' UTC (exclusive).' }}</p>
      <p class="mt-4"><strong>{{ preview.truncated ? 'At least ' : '' }}{{ preview.matched }}</strong> age-matched headers{{ preview.truncated ? ' shown; more exist. Counts below cover only this sample.' : ' at scan time.' }}</p>
      <div class="flex gap-4 mt-4"><Tag :value="'Incomplete / unknown session: ' + preview.sessionBlocked" severity="warn" /><Tag :value="'Shared body: ' + preview.sharedBody" severity="warn" /><Tag :value="'Missing body ID: ' + preview.missingBodyId" severity="warn" /></div>
      <p v-if="preview.classInfo.purgeProtected" class="mt-4">ENSPURGE=0: standard purge preserves this class's bodies, but can still delete their headers.</p>
      <p v-if="!preview.classInfo.persistent" class="mt-4">The body class is missing or is not persistent. Header metadata alone cannot establish its cleanup behavior.</p>
      <p class="mt-4">These are overlapping caution counts, not numbers safe to delete. Bodies, streams, external references and delete callbacks are not inspected. Concurrent production activity can change the result.</p>
      <details class="mt-4"><summary>Inspect matching headers</summary><DataTable :value="preview.rows" paginator :rows="10" class="mt-4">
        <Column field="ID" header="Header ID" /><Column field="SessionId" header="Session" /><Column field="CreatedUTC" header="Created UTC" /><Column field="Status" header="Status code" />
        <Column header="Session"><template #body="{data}">{{ data.SessionBlocked ? 'Incomplete / unknown' : 'Terminal header statuses' }}</template></Column>
        <Column header="Body"><template #body="{data}">{{ data.MissingBodyId ? 'Missing ID' : data.SharedBody ? 'Referenced by another header' : 'Single header reference' }}</template></Column>
      </DataTable></details>
    </template></Card>
    <details><summary class="cursor-pointer font-semibold">Example messages (optional demonstration)</summary><div class="mt-4"><ext-slot name="examples" ctx="loadedNamespace" layout="stack" /></div></details>
    <details><summary class="cursor-pointer">Recent activity</summary><Card><template #title>Recent activity · {{ loadedNamespace }}</template><template #content>
      <DataTable :value="history" paginator :rows="5"><template #empty>No recorded activity.</template>
        <Column field="AtUTC" header="UTC" /><Column field="Actor" header="Actor" /><Column field="Operation" header="Outcome" /><Column field="BodyClass" header="Body class" />
        <Column header="Details"><template #body="{data}"><details><summary>View</summary><pre style="white-space:pre-wrap">{{ data.Details }}</pre></details></template></Column>
      </DataTable>
    </template></Card>
    </details>
    <ext-slot name="footer" layout="stack" />
  </template>
</div>
}
}
