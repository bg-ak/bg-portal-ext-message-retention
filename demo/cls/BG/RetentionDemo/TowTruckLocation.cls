/// Synthetic tow-truck telemetry; no real vehicle or customer data.
Class BG.RetentionDemo.TowTruckLocation Extends %Persistent
{
Property VehicleId As %String;
Property Latitude As %Numeric(SCALE = 6);
Property Longitude As %Numeric(SCALE = 6);
}
