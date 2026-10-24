// ProjectFolder is a Text parameter containing the repository root.
// This is the actual Parquet fact query used by the delivered report.
let
    Source = Parquet.Document(File.Contents(ProjectFolder & "/notebooks/data/processed/fact_flight.parquet")),
    Selected = Table.RemoveColumns(Source, {"flight_key", "candidate_operational_key"}),
    Typed = Table.TransformColumnTypes(Selected, {{"flight_date", type date}, {"source_row_number", Int64.Type}, {"cancelled", Int64.Type}, {"diverted", Int64.Type}, {"departure_hour", Int64.Type}, {"peak_period", Int64.Type}}),
    Coverage = Table.AddColumn(Typed, "Airport code type", each if Text.Length([origin_airport_code]) = 3 then "IATA" else "Numeric ID", type text),
    Period = Table.AddColumn(Coverage, "Departure period", each if [peak_period] = 1 then "Peak (06-09 / 16-19)" else "Other scheduled hours", type text)
in
    Period
