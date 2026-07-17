# Lessons

### Recommendation scope
Do not turn a final-art request into a graybox-art phase; use temporary art only where the design explicitly allows it.

### GDScript static context
Autoload identifiers (e.g. BalanceData) fail to compile inside static functions in Godot 4.7 ("Identifier not found") — despite CLAUDE.md's `static var := BalanceData.get_value(...)` example; fetch the autoload via `(Engine.get_main_loop() as SceneTree).root.get_node_or_null("BalanceData")` instead (see class_stats.gd `_balance()`).

### Godot web export
Files read via FileAccess (e.g. data/balance.csv) must have importer="keep" in their .import and match the preset's include_filter, or the web build silently runs on code fallbacks; Godot's default csv_translation import replaces the raw file in the pck.
