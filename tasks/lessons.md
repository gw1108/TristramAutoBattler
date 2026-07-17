# Lessons

### Recommendation scope
Do not turn a final-art request into a graybox-art phase; use temporary art only where the design explicitly allows it.

### Godot web export
Files read via FileAccess (e.g. data/balance.csv) must have importer="keep" in their .import and match the preset's include_filter, or the web build silently runs on code fallbacks; Godot's default csv_translation import replaces the raw file in the pck.
