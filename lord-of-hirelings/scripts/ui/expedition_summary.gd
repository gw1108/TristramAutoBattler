extends Control
## Expedition Summary Day X (GDD "post dungeon expedition summary panel";
## mockups/expedition-summary.html) — the payoff screen of the whole day loop.
## Opens over the town when the expedition returns, reading the dictionary
## Expedition.resolve already built; it renders that ledger and never recomputes
## it. The panel sits at ~80% of the window in both dimensions and scrolls its
## results area vertically if the columns do not fit.
##
## One column per dive, left to right, each the same width and each reserving
## vertical space for 3 adventurers — an empty party never existed, so it has no
## dive and gets no column (the columns come from summary["dives"], not from the
## party count). Above each column is its dungeon level's biome; parties pick
## the hardest level they are gated for, so columns can show different biomes.
##
## Per living member: current-level banner, XP bar, next-level banner, then the
## coin pile they are taking home to spend at the player's shops. The pile is
## their OWN gold (gold_kept) — the player earns nothing directly from the
## dungeon, only the tax-copy on the footer line, which is minted alongside
## these piles rather than cut out of them. The dead show no bar, no banners and
## no coins: their purse and gear are destroyed, so their row reads as nothing
## kept and no level gained, which is exactly what Expedition already wrote onto
## it (gold_kept 0, levels_gained 0).
##
## This is where levelling up is celebrated, though not where it is applied —
## the roster was already paid before nightfall dissolved the parties, and this
## animates what landed. The XP bar therefore LOOPS rather than assuming a
## single level-up: a full dungeon 1 clear is worth 22 XP, nearly two levels to
## a fresh recruit (level 2 with 14/16 toward level 3). It fills to full, both
## banners increment, the bar snaps to empty, and it repeats until the leftover
## XP is placed. Fled adventurers still level up — they keep every point banked
## before they ran.

## The player dismissed the panel. The win panel is timed to this exact moment
## (GDD: it appears "the moment the winning expedition's summary is closed").
signal closed

const TITLE_FONT := preload("res://fonts/pixel-operator/PixelOperator-Bold.ttf")
const BODY_FONT := preload("res://fonts/pixel-operator/PixelOperator8.ttf")
const VARIANT_SHEET := preload("res://sprites/recruits/recruit_variants.png")
const HiredAdventurerScript := preload("res://scripts/town/hired_adventurer.gd")

## Style-guide UI palette (same family as HeroPanel / InteractPrompt).
const COLOR_BG := Color("26262e")
const COLOR_BORDER := Color("6b6b7a")
const COLOR_TEXT := Color(0.93, 0.89, 0.75)
const COLOR_MUTED := Color(0.65, 0.67, 0.73)
const COLOR_GOLD := Color(0.98, 0.82, 0.35)
const COLOR_GOOD := Color("7ec97e")
const COLOR_BAD := Color("dd6666")
## The world dims behind the panel so the payoff screen reads as modal.
const COLOR_SCRIM := Color(0.04, 0.04, 0.06, 0.72)
const COLOR_BAR_BG := Color("101014")
const COLOR_BAR_EDGE := Color("555560")
const COLOR_XP := Color("d4b000")
## A banner the adventurer has just climbed past, vs a plain one (mockup).
const COLOR_BANNER := Color("4a3a22")
const COLOR_BANNER_HOT := Color("7a5a1a")
## What a corpse is tinted as it falls.
const COLOR_DEAD_TINT := Color(1.0, 0.42, 0.42)

const SHEET_CELL_PX := 48

## The dungeon level biomes (GDD "Dungeon level biome backdrops"), top-to-bottom
## gradient stops: 1 gentle grassy forest, 2 swampy forest, 3 underground undead
## crypt, 4 volcanic lava fields. Levels 1-2 are the mockup's own gradients.
const BIOME_STOPS := {
	1: [Color("7fb069"), Color("4a7a3a"), Color("2e5426")],
	2: [Color("5a6b52"), Color("3a4a35"), Color("232e20")],
	3: [Color("4a4658"), Color("2f2c3a"), Color("1b1a24")],
	4: [Color("8a3a1e"), Color("4a1f14"), Color("21100c")],
}
const BIOME_HEIGHT := 64

## The GDD's interchangeable verbs for a killing blow. Picked by a stable hash of
## the victim's name so one adventurer's epitaph never rewords itself.
const DEATH_VERBS: Array[String] = [
	"Murdered", "Slain", "Killed", "Defeated",
	"Crushed", "Devastated", "Demolished", "Destroyed",
]

var _panel: PanelContainer
var _title_label: Label
var _columns_box: HBoxContainer
var _tax_label: Label
## One entry per rendered member row: the nodes its animation drives, grouped by
## column so the columns can animate one at a time, left to right.
var _columns: Array = []
## Bumped every time the panel is rebuilt. A running animation checks it after
## every await and bails if it is stale, so reopening the panel can never leave
## an old coroutine writing to freed nodes.
var _generation := 0


func _ready() -> void:
	add_to_group("expedition_summary")
	hide()
	# ~80% of the window in both dimensions, tracked through resizes rather than
	# measured once (GDD).
	var fraction := clampf(
		BalanceData.get_value("summary_panel_screen_fraction", 0.8), 0.1, 1.0)
	var margin := (1.0 - fraction) * 0.5
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = COLOR_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	_panel = PanelContainer.new()
	_panel.anchor_left = margin
	_panel.anchor_top = margin
	_panel.anchor_right = 1.0 - margin
	_panel.anchor_bottom = 1.0 - margin
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(COLOR_BG, 0.98)
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(8.0)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	_build_frame()


## Show the panel for a resolved expedition (an Expedition.resolve dictionary)
## and animate it. Public so the dungeon entrance — and a harness — can open it.
func open(summary: Dictionary) -> void:
	if summary.is_empty():
		return
	_generation += 1
	_title_label.text = "Expedition Summary Day %d" % int(summary.get("day", 0))
	var earned := int(summary.get("gold_earned", 0))
	# The tax-copy is minted, not deducted: the piles below keep every coin.
	_tax_label.text = "Your tax-copy: +%d gold (10%% of the %d gold they earned)" \
			% [int(summary.get("tax_copy", 0)), earned]
	_build_columns(summary.get("dives", []))
	show()
	_animate(_generation)


func _build_frame() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	_panel.add_child(root)
	_title_label = Label.new()
	_title_label.add_theme_font_override("font", TITLE_FONT)
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title_label)
	root.add_child(_separator())
	# The results area is the only thing that scrolls; title, tax line and Close
	# stay pinned to the panel (GDD).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_columns_box = HBoxContainer.new()
	_columns_box.add_theme_constant_override("separation", 0)
	_columns_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_columns_box)
	root.add_child(_separator())
	_tax_label = _label("", COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_tax_label)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(button_row)
	var close := _button("Close")
	close.pressed.connect(_on_close_pressed)
	button_row.add_child(close)


func _build_columns(dives: Array) -> void:
	for child in _columns_box.get_children():
		child.queue_free()
		_columns_box.remove_child(child)
	_columns.clear()
	for i in dives.size():
		var dive: Dictionary = dives[i]
		if i > 0:
			var divider := ColorRect.new()
			divider.color = COLOR_BORDER
			divider.custom_minimum_size = Vector2(1, 0)
			_columns_box.add_child(divider)
		# Every column is the same width whatever it holds (GDD).
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_stretch_ratio = 1.0
		column.add_theme_constant_override("separation", 6)
		_columns_box.add_child(column)
		column.add_child(_biome_header(int(dive.get("dungeon_level", 1))))
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 8)
		# Always room for a full party of 3, so a column with one survivor does
		# not collapse and re-rank the panel (GDD).
		rows.custom_minimum_size.y = 3.0 * BalanceData.get_value(
			"summary_member_row_min_height", 56.0)
		column.add_child(rows)
		var entries: Array = []
		for row in dive.get("members", []):
			entries.append(_build_member_row(rows, row, dive))
		_columns.append(entries)


## The dungeon level this party traversed, as a band of its biome's colors with
## the level called out in the corner (mockup).
func _biome_header(dungeon_level: int) -> Control:
	var header := Control.new()
	header.custom_minimum_size.y = BIOME_HEIGHT
	var gradient := Gradient.new()
	var stops: Array = BIOME_STOPS.get(dungeon_level, BIOME_STOPS[1])
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient.colors = PackedColorArray([stops[0], stops[1], stops[2]])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 1
	texture.height = BIOME_HEIGHT
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	header.add_child(rect)
	var level_label := _label("LEVEL %d" % dungeon_level, Color(1, 1, 1, 0.75),
			HORIZONTAL_ALIGNMENT_LEFT)
	level_label.position = Vector2(4, 2)
	header.add_child(level_label)
	return header


## One adventurer's row: sprite, name, the level/XP/level/coins strip, and the
## status line that says how their day ended.
func _build_member_row(parent: VBoxContainer, row: Dictionary, dive: Dictionary) -> Dictionary:
	var alive: bool = row.get("alive", true)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(SHEET_CELL_PX, SHEET_CELL_PX)
	box.add_child(icon_holder)
	var icon := TextureRect.new()
	icon.texture = _class_icon(row.get("class", ""))
	icon.size = Vector2(SHEET_CELL_PX, SHEET_CELL_PX)
	# Rotating about the middle is what lets a corpse lie down in place.
	icon.pivot_offset = Vector2(SHEET_CELL_PX, SHEET_CELL_PX) * 0.5
	icon_holder.add_child(icon)
	var blood := DeadMark.new()
	blood.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood.hide()
	icon_holder.add_child(blood)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 2)
	box.add_child(body)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	body.add_child(name_row)
	name_row.add_child(_label(row.get("name", ""), COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var levelup := _label("Level up!", COLOR_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	levelup.hide()
	name_row.add_child(levelup)
	var entry := {
		"row": row,
		"icon": icon,
		"blood": blood,
		"levelup": levelup,
	}
	if alive:
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 4)
		body.add_child(strip)
		var start_level: int = int(row.get("start_level", 1))
		var current := Banner.new(start_level, COLOR_BANNER)
		strip.add_child(current)
		var bar := _xp_bar()
		strip.add_child(bar)
		var next := Banner.new(start_level + 1, COLOR_BANNER)
		strip.add_child(next)
		# The coins are hidden until the XP that bought them has been placed,
		# and stay hidden for good at 0 gold (GDD).
		var coins := VBoxContainer.new()
		coins.add_theme_constant_override("separation", 0)
		strip.add_child(coins)
		var pile := CoinPile.new()
		pile.set_gold(int(row.get("gold_kept", 0)))
		coins.add_child(pile)
		coins.add_child(_label("+%d" % int(row.get("gold_kept", 0)), COLOR_GOLD,
				HORIZONTAL_ALIGNMENT_CENTER))
		coins.visible = false
		entry["bar"] = bar
		entry["banner_current"] = current
		entry["banner_next"] = next
		entry["coins"] = coins
	var status := _label(_status_text(row, dive), _status_color(row, dive),
			HORIZONTAL_ALIGNMENT_LEFT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	return entry


## How this adventurer's day ended, in the GDD's four phrasings.
func _status_text(row: Dictionary, dive: Dictionary) -> String:
	if not row.get("alive", true):
		var killer: String = row.get("killed_by", "")
		if killer.is_empty():
			return "Died in the dungeon"
		return "%s by a %s" % [_death_verb(row.get("name", "")), killer]
	if dive.get("completed", false):
		var dungeon_level := int(dive.get("dungeon_level", 1))
		if dungeon_level >= Expedition.MAX_DUNGEON_LEVEL:
			return "Conquered the final dungeon"
		return "Heroically cleared the way to Level %d" % (dungeon_level + 1)
	# Anyone still standing on a dive that did not clear was pushed back out —
	# a panic flee, a retreat off a wipe, or the stalemate rule.
	return "Fled"


func _status_color(row: Dictionary, dive: Dictionary) -> Color:
	if not row.get("alive", true):
		return COLOR_BAD
	return COLOR_GOOD if dive.get("completed", false) else COLOR_MUTED


## Stable per-adventurer pick from the GDD's verb list — an epitaph should not
## reword itself if the panel is ever rebuilt.
func _death_verb(display_name: String) -> String:
	return DEATH_VERBS[absi(display_name.hash()) % DEATH_VERBS.size()]


func _animate(generation: int) -> void:
	var column_gap := BalanceData.get_value("summary_column_stagger_seconds", 0.5)
	var member_gap := BalanceData.get_value("summary_member_stagger_seconds", 0.2)
	# One by one, left to right (GDD).
	for column in _columns:
		for entry in column:
			await _animate_member(entry, generation)
			if _generation != generation:
				return
			await _wait(member_gap)
			if _generation != generation:
				return
		await _wait(column_gap)
		if _generation != generation:
			return


func _animate_member(entry: Dictionary, generation: int) -> void:
	var row: Dictionary = entry["row"]
	if not row.get("alive", true):
		await _animate_death(entry, generation)
		return
	if int(row.get("levels_gained", 0)) > 0:
		entry["levelup"].show()
	var bar: ProgressBar = entry["bar"]
	var level := int(row.get("start_level", 1))
	var xp := _start_xp(row)
	var earned := int(row.get("xp_earned", 0))
	bar.value = float(xp) / float(Expedition.xp_to_next_level(level))
	# Loops until the leftover XP is placed: one clear can be worth several
	# levels, so this can never assume a single threshold (GDD).
	while earned > 0:
		var to_next := Expedition.xp_to_next_level(level)
		var needed := to_next - xp
		if earned < needed:
			xp += earned
			earned = 0
			await _fill_to(bar, float(xp) / float(to_next), generation)
			break
		earned -= needed
		await _fill_to(bar, 1.0, generation)
		if _generation != generation:
			return
		# Both banners climb together and the bar starts the next level empty.
		level += 1
		xp = 0
		entry["banner_current"].set_number(level)
		entry["banner_current"].set_banner_color(COLOR_BANNER_HOT)
		entry["banner_next"].set_number(level + 1)
		bar.value = 0.0
		await _wait(BalanceData.get_value("summary_level_up_pause_seconds", 0.35))
	if _generation != generation:
		return
	entry["coins"].visible = int(row.get("gold_kept", 0)) > 0


## The corpse lies down, tinted red, and the blood lands with it (GDD).
func _animate_death(entry: Dictionary, generation: int) -> void:
	var icon: TextureRect = entry["icon"]
	var duration := maxf(BalanceData.get_value("summary_death_anim_seconds", 0.4), 0.01)
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		if _generation != generation or not is_instance_valid(icon):
			return
		elapsed += get_process_delta_time()
		var t := minf(elapsed / duration, 1.0)
		icon.rotation_degrees = 90.0 * t
		icon.modulate = Color.WHITE.lerp(COLOR_DEAD_TINT, t)
	entry["blood"].show()


## Sweep the bar to [param target], at a pace set by how far it has to travel so
## a long fill never reads faster than a short one.
func _fill_to(bar: ProgressBar, target: float, generation: int) -> void:
	var from: float = bar.value
	var span := absf(target - from)
	if span <= 0.001:
		bar.value = target
		return
	var duration := maxf(
		BalanceData.get_value("summary_xp_bar_fill_seconds", 0.9) * span, 0.01)
	var elapsed := 0.0
	while elapsed < duration:
		# Driven off frames rather than a Tween: the panel can be closed and
		# reopened mid-fill, and a frame loop that re-checks the generation can
		# never be left awaiting a tween that died with its node.
		await get_tree().process_frame
		if _generation != generation or not is_instance_valid(bar):
			return
		elapsed += get_process_delta_time()
		bar.value = lerpf(from, target, minf(elapsed / duration, 1.0))
	bar.value = target


## The XP this adventurer walked in carrying. Expedition reports where they
## ended (start_level, level, xp) and what the dive paid (xp_earned), so the
## start of the animation is what is left after unwinding the earnings back
## through every level they climbed. Only ever asked of a living row: a dead one
## banks nothing, so its bar is never drawn.
func _start_xp(row: Dictionary) -> int:
	var total := int(row.get("xp", 0))
	for level in range(int(row.get("start_level", 1)), int(row.get("level", 1))):
		total += Expedition.xp_to_next_level(level)
	return maxi(total - int(row.get("xp_earned", 0)), 0)


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout


func _on_close_pressed() -> void:
	# Stops whatever is still animating: every await re-checks the generation.
	_generation += 1
	hide()
	closed.emit()


func _class_icon(adventurer_class: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = VARIANT_SHEET
	var col: int = HiredAdventurerScript.CLASS_VARIANTS.get(adventurer_class, 0)
	atlas.region = Rect2(col * SHEET_CELL_PX, 0, SHEET_CELL_PX, SHEET_CELL_PX)
	return atlas


func _xp_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(24, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var background := StyleBoxFlat.new()
	background.bg_color = COLOR_BAR_BG
	background.border_color = COLOR_BAR_EDGE
	background.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = COLOR_XP
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", COLOR_GOLD)
	button.add_theme_color_override("font_hover_color", COLOR_GOLD)
	button.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("4a3a22")
	normal.border_color = Color("c9a15a")
	normal.set_border_width_all(1)
	normal.set_content_margin_all(4.0)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("5c4829")
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("2f2415")
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _label(text: String, color: Color, alignment: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment as HorizontalAlignment
	return label


func _separator() -> ColorRect:
	var line := ColorRect.new()
	line.color = COLOR_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	return line


## A level number on a shield banner, in the hero panel's family (mockup
## .banner.inline): a pennant with a V cut out of its foot.
class Banner:
	extends Control

	const FONT := preload("res://fonts/pixel-operator/PixelOperator8.ttf")
	const FONT_SIZE := 8
	const TEXT_COLOR := Color("ffe9b0")

	var _number := 1
	var _color := Color("4a3a22")

	func _init(number: int, color: Color) -> void:
		_number = number
		_color = color
		custom_minimum_size = Vector2(14, 18)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_number(number: int) -> void:
		_number = number
		queue_redraw()

	func set_banner_color(color: Color) -> void:
		_color = color
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.7),
			Vector2(w * 0.5, h), Vector2(0, h * 0.7),
		]), _color)
		var text := str(_number)
		var text_width := FONT.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(FONT, Vector2((w - text_width) * 0.5, h * 0.62).round(), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)


## The adventurer's haul as a pile that grows richer with the gold: 1 coin per
## 3-6 gold earned, at least 1 for any gold at all, capped at 100 coins (GDD).
## Coins overlap and stack in rows from the floor up, so a big purse reads as a
## heap rather than a longer line.
class CoinPile:
	extends Control

	const FACE := Color("f0c94a")
	const EDGE := Color("8a6410")
	const COIN_PX := 5
	const STEP_X := 4
	const STEP_Y := 3
	const PER_ROW := 10

	var _coins := 0

	func _init() -> void:
		custom_minimum_size = Vector2(
			(PER_ROW - 1) * STEP_X + COIN_PX, 10 * STEP_Y + COIN_PX)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_gold(gold: int) -> void:
		_coins = 0
		if gold > 0:
			var per_coin := maxf(
				BalanceData.get_value("summary_coin_gold_per_coin", 4.5), 0.1)
			var cap := int(BalanceData.get_value("summary_coin_max", 100.0))
			_coins = clampi(ceili(gold / per_coin), 1, cap)
		queue_redraw()

	func _draw() -> void:
		for i in _coins:
			var x := float(i % PER_ROW * STEP_X)
			var y := size.y - COIN_PX - float(i / PER_ROW * STEP_Y)
			draw_rect(Rect2(x, y, COIN_PX, COIN_PX), EDGE)
			draw_rect(Rect2(x + 1, y + 1, COIN_PX - 2, COIN_PX - 2), FACE)


## Blood splatter under a fallen adventurer (GDD).
class DeadMark:
	extends Control

	const BLOOD := Color("8b1a1a")
	const DARK := Color("5e0f0f")
	## Splats in the sprite cell's own 48x48 space, {x, y, w, h}.
	const SPLATS: Array[Rect2] = [
		Rect2(10, 38, 26, 4),
		Rect2(6, 34, 6, 3),
		Rect2(36, 36, 5, 3),
		Rect2(30, 42, 9, 2),
	]

	func _draw() -> void:
		for i in SPLATS.size():
			draw_rect(SPLATS[i], BLOOD if i % 2 == 0 else DARK)
