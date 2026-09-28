/// Native shell and PrimeVue components, emitted by Bloom; no frontend build.
Class BG.Retention.Portal.Page Extends Portal.Page
{
Parameter RESOURCE = "BG_RetentionView";
Parameter PAGEID = "retention.planner";
Parameter TITLE = "Production Message Retention";

Property target As %String [ InitialExpression = {$namespace} ];
Property loadedNamespace As %String;
Property rules As %DynamicArray [ InitialExpression = {[]} ];
Property history As %DynamicArray [ InitialExpression = {[]} ];
Property classes As %DynamicArray [ InitialExpression = {[]} ];
Property form As %DynamicObject [ InitialExpression = {{"BodyClass":"","Mode":"days","KeepDays":30,"Revision":0}} ];
Property modes As %DynamicArray [ InitialExpression = {[{"label":"Keep for days","value":"days"},{"label":"Never expire","value":"never"}]} ];
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
        set ..rules = ##class(BG.Retention.Service).Rules(..loadedNamespace)
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

ClassMethod ReadView(target As %String) As %String [ WebMethod ]
{
    try {
        do ##class(BG.Retention.Portal.Access).Check()
        set target = ##class(BG.Retention.Service).Target(target)
        return {"ok":true,"namespace":(target),"rules":(##class(BG.Retention.Service).Rules(target)),"history":(##class(BG.Retention.Service).History(target)),"canEdit":($system.Security.Check("BG_RetentionEdit","USE"))}.%ToJSON()
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
        return ..ActionResult(##class(BG.Retention.Service).Save(target, obj.BodyClass, obj.Mode, obj.KeepDays, obj.Revision))
    } catch ex { return ..ActionResult(ex.AsStatus()) }
}

ClassMethod Analyze(target As %String, json As %String) As %String [ WebMethod ]
{
    try {
        do ##class(BG.Retention.Portal.Access).Check()
        set obj = {}.%FromJSON(json)
        return {"ok":true,"preview":(##class(BG.Retention.Service).Preview(target,obj.BodyClass,obj.Mode,obj.KeepDays))}.%ToJSON()
    } catch ex { return ..ActionResult(ex.AsStatus()) }
}

ClientMethod load() [ Language = javascript ]
{
    this.busy = true; this.error = ''; this.notice = ''; this.preview = {};
    try {
        const r = JSON.parse(await this.ReadView(this.target));
        if (!r.ok) throw new Error(r.error);
        this.loadedNamespace = r.namespace; this.target = r.namespace;
        this.rules = r.rules; this.history = r.history; this.canEdit = !!r.canEdit;
        this.classes = []; this.newRule();
    } catch (e) { this.error = e.message; this.loadedNamespace = ''; this.rules = []; this.history = []; }
    finally { this.busy = false; }
}

ClientMethod discoverTypes() [ Language = javascript ]
{
    this.busy = true; this.error = '';
    try {
        const r = JSON.parse(await this.Discover(this.loadedNamespace));
        if (!r.ok) throw new Error(r.error);
        this.classes = r.inventory.classes;
        this.notice = 'Types from ' + r.inventory.headersInspected + ' recent headers. ' + (r.inventory.truncated ? 'Inventory is partial; you can enter another exact class.' : 'No message bodies were read.');
    } catch (e) { this.error = e.message; }
    finally { this.busy = false; }
}

ClientMethod newRule() [ Language = javascript ]
{
    this.form = { BodyClass: '', Mode: 'days', KeepDays: 30, Revision: 0 }; this.preview = {};
}

ClientMethod editRule(row) [ Language = javascript ]
{
    this.form = { ...row }; this.preview = {}; this.notice = ''; this.error = '';
}

ClientMethod chooseClass(value) [ Language = javascript ]
{
    const existing = this.rules.find(r => r.BodyClass === value);
    this.editRule(existing || { BodyClass: value, Mode: 'days', KeepDays: 30, Revision: 0 });
}

ClientMethod save() [ Language = javascript ]
{
    this.busy = true; this.error = ''; this.preview = {};
    try {
        const r = JSON.parse(await this.SaveRule(this.loadedNamespace, JSON.stringify(this.form)));
        if (!r.ok) throw new Error(r.error);
        const cls = this.form.BodyClass;
        const view = JSON.parse(await this.ReadView(this.loadedNamespace));
        if (!view.ok) throw new Error(view.error);
        this.rules = view.rules; this.history = view.history;
        this.editRule(this.rules.find(x => x.BodyClass === cls));
        this.notice = 'Planning policy saved. No purge task or IRIS purge setting was changed.';
    } catch (e) { this.error = e.message; }
    finally { this.busy = false; }
}

ClientMethod runPreview() [ Language = javascript ]
{
    this.busy = true; this.error = ''; this.notice = ''; this.preview = {};
    try {
        const r = JSON.parse(await this.Analyze(this.loadedNamespace, JSON.stringify(this.form)));
        if (!r.ok) throw new Error(r.error);
        this.preview = r.preview;
        const view = JSON.parse(await this.ReadView(this.loadedNamespace));
        if (view.ok) this.history = view.history;
    } catch (e) { this.error = e.message; }
    finally { this.busy = false; }
}

XData Template [ MimeType = text/vue ]
{
<div class="flex flex-col gap-4">
  <div><h1 class="text-2xl font-semibold">Production Message Retention</h1>
    <p class="text-sm text-gray-500 mt-1">Planning policies and read-only impact analysis · <a href="https://github.com/bg-ak/bg-portal-ext-message-retention" class="text-blue-600 hover:underline">Extension source and installation</a></p></div>
  <Card><template #content>
    <Tag value="Preview only · cleanup is not implemented" severity="warn" />
    <p class="mt-4">Rules do not control the built-in IRIS purge task. “Never expire” records your intent; it does not protect messages from other purge jobs. Unconfigured types have no expiry in this planner.</p>
  </template></Card>
  <div class="flex items-center gap-4">
    <label for="retention-namespace">Production namespace</label>
    <InputText id="retention-namespace" v-model="target" :disabled="busy" @keyup.enter="load" />
    <PButton label="Load namespace" icon="pi pi-refresh" @click="load" :disabled="busy" />
  </div>
  <p v-if="error" role="alert" class="text-red-600">{{ error }}</p>
  <p v-if="notice" role="status">{{ notice }}</p>
  <template v-if="loadedNamespace">
    <Card><template #title>Policies · {{ loadedNamespace }}</template><template #content>
      <PButton label="New policy" icon="pi pi-plus" text @click="newRule" :disabled="busy" />
      <DataTable :value="rules" dataKey="BodyClass" paginator :rows="10" @row-click="!busy && editRule($event.data)">
        <template #empty>No policies. Start with an actual message body class.</template>
        <Column field="BodyClass" header="Exact body class" sortable />
        <Column header="Retention"><template #body="{data}">{{ data.Mode === 'never' ? 'Never expire' : data.KeepDays + ' days' }}</template></Column>
        <Column field="UpdatedBy" header="Changed by" />
        <Column field="UpdatedAt" header="Changed UTC" />
        <Column><template #body="{data}"><PButton label="Open" text @click="editRule(data)" :disabled="busy" /></template></Column>
      </DataTable>
    </template></Card>
    <Card><template #title>{{ form.Revision ? 'Edit policy' : 'New policy / what-if' }} · {{ loadedNamespace }}</template><template #content>
      <div class="flex flex-col gap-4">
        <div class="flex items-center gap-4"><PButton label="Discover message types" icon="pi pi-search" @click="discoverTypes" :disabled="busy" /><span class="text-sm text-gray-500">Reads up to 1,000 recent headers.</span></div>
        <Select v-if="classes.length" :options="classes" placeholder="Choose an observed body class" @update:modelValue="chooseClass" :disabled="busy" aria-label="Observed message types" />
        <label for="retention-class">Exact message body class</label>
        <InputText id="retention-class" v-model="form.BodyClass" :disabled="busy || !!form.Revision" @update:modelValue="preview = {}" />
        <label for="retention-mode">Retention</label>
        <Select inputId="retention-mode" v-model="form.Mode" :options="modes" optionLabel="label" optionValue="value" :disabled="busy" @update:modelValue="preview = {}" />
        <template v-if="form.Mode === 'days'"><label for="retention-days">Days (1–36,500)</label>
          <InputText id="retention-days" v-model="form.KeepDays" type="number" min="1" max="36500" :disabled="busy" @update:modelValue="preview = {}" />
          <p class="text-sm text-gray-500">A day means 24 hours. Match headers strictly older than the UTC cutoff, using TimeCreated.</p></template>
        <div class="flex gap-4">
          <PButton label="Preview this rule" icon="pi pi-eye" @click="runPreview" :disabled="busy || !form.BodyClass" />
          <PButton v-if="canEdit" label="Save planning policy" icon="pi pi-save" severity="secondary" @click="save" :disabled="busy || !form.BodyClass" />
        </div>
      </div>
    </template></Card>
    <Card v-if="preview.asOfUTC"><template #title>Preview · {{ preview.namespace }} · {{ preview.bodyClass }}</template><template #content>
      <p>Observed at {{ preview.asOfUTC }} UTC. {{ preview.mode === 'never' ? 'No age expiry; no header scan was needed.' : 'Age cutoff: ' + preview.cutoffUTC + ' UTC (exclusive).' }}</p>
      <p class="mt-4"><strong>{{ preview.truncated ? 'At least ' : '' }}{{ preview.matched }}</strong> age-matched headers{{ preview.truncated ? ' shown; more exist. Counts below cover only this sample.' : ' at scan time.' }}</p>
      <div class="flex gap-4 mt-4"><Tag :value="'Incomplete / unknown session: ' + preview.sessionBlocked" severity="warn" /><Tag :value="'Shared body: ' + preview.sharedBody" severity="warn" /><Tag :value="'Missing body ID: ' + preview.missingBodyId" severity="warn" /></div>
      <p v-if="preview.classInfo.purgeProtected" class="mt-4">ENSPURGE=0: standard purge preserves this class's bodies, but can still delete their headers.</p>
      <p v-if="!preview.classInfo.persistent" class="mt-4">The body class is missing or is not persistent. Header metadata alone cannot establish its cleanup behavior.</p>
      <p class="mt-4">These are overlapping caution counts, not numbers safe to delete. Bodies, streams, external references and delete callbacks are not inspected. Concurrent production activity can change the result.</p>
      <DataTable :value="preview.rows" paginator :rows="10" class="mt-4">
        <Column field="ID" header="Header ID" /><Column field="SessionId" header="Session" /><Column field="CreatedUTC" header="Created UTC" /><Column field="Status" header="Status code" />
        <Column header="Session"><template #body="{data}">{{ data.SessionBlocked ? 'Incomplete / unknown' : 'Terminal header statuses' }}</template></Column>
        <Column header="Body"><template #body="{data}">{{ data.MissingBodyId ? 'Missing ID' : data.SharedBody ? 'Referenced by another header' : 'Single header reference' }}</template></Column>
      </DataTable>
    </template></Card>
    <Card><template #title>Recent activity · {{ loadedNamespace }}</template><template #content>
      <DataTable :value="history" paginator :rows="5"><template #empty>No recorded activity.</template>
        <Column field="AtUTC" header="UTC" /><Column field="Actor" header="Actor" /><Column field="Operation" header="Outcome" /><Column field="BodyClass" header="Body class" />
        <Column header="Details"><template #body="{data}"><details><summary>View</summary><pre style="white-space:pre-wrap">{{ data.Details }}</pre></details></template></Column>
      </DataTable>
    </template></Card>
    <ext-slot name="footer" layout="stack" />
  </template>
</div>
}
}
