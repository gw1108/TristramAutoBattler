extends PanelContainer
## Hero stat panel (mockups/hero-panel.html Variants A and B; GDD hero panel).
## Opens when the player left-clicks a hired adventurer wandering the town —
## mouse only, no keyboard interact required. Header: first name as title,
## epithet as subtitle, class sprite + level on the left, personal gold on
## the right. Below: the BalanceNumbers stat block (evasion/accuracy shown as
## percentages vs the reference grunt via ClassStats), the always-three-row
## tier-0 inventory, and the current activity. Any left-click outside the
## panel closes it; clicking another adventurer switches to them (the close
## runs on unhandled input, the open on physics picking, which the viewport
## processes afterwards).
## Variant B: left-clicking an unhired recruit at the inn opens the same
## panel via open_for_recruit with a "Looking for work" activity plus a hire
## section — class name, one-line class description, and Hire / Hire and
## Sponsor buttons (mouse-only hire path alongside the recruit's [E] prompt).

const TITLE_FONT := preload("res://fonts/pixel-operator/PixelOperator-Bold.ttf")
const BODY_FONT := preload("res://fonts/pixel-operator/PixelOperator8.ttf")
const VARIANT_SHEET := preload("res://sprites/recruits/recruit_variants.png")
const HiredAdventurerScript := preload("res://scripts/town/hired_adventurer.gd")

## Style-guide UI palette (same family as InteractPrompt).
const COLOR_BG := Color("26262e")
const COLOR_BORDER := Color("6b6b7a")
const COLOR_TEXT := Color(0.93, 0.89, 0.75)
const COLOR_MUTED := Color(0.65, 0.67, 0.73)
const COLOR_GOLD := Color(0.98, 0.82, 0.35)

const PANEL_WIDTH := 232.0
const SHEET_CELL_PX := 48

## Tier-0 item names per class, [weapon, armor, jewelry] (BalanceNumbers
## "Item names"). The inventory always lists all three slots because every
## adventurer arrives wearing tier 0 in each; higher tiers come with the
## shop-inventory slice.
const TIER0_ITEMS := {
	"Knight": ["Rusted Longsword", "Dented Hauberk", "Frayed Sword-Belt"],
	"Captain": ["Cracked Spear", "Frayed Gambeson", "Tarnished Whistle"],
	"Berserker": ["Chipped Axe", "Torn Furs", "Bent Iron Ring"],
	"Mage": ["Splintered Wand", "Moth-Eaten Robes", "Clouded Bead"],
	"Rogue": ["Notched Knife", "Patchwork Cloak", "Bent Copper Ring"],
	"Cleric": ["Cracked Censer", "Threadbare Habit", "Cracked Prayer-Bead"],
}

## One-line class descriptions for the Variant B hire section, phrased after
## the GDD "Class roles" lines (Mage's is the mockup's verbatim).
const CLASS_DESCRIPTIONS := {
	"Knight": "Tanky, with defensive abilities to shield the party.",
	"Captain": "Restores morale and boosts his comrades' damage.",
	"Berserker": "Hits hard, and can take a hit in return.",
	"Mage": "Hurls elemental ruin at every enemy at once. Devastating, but fragile.",
	"Rogue": "High single-target damage, with decent health and defense.",
	"Cleric": "No attack of their own; keeps the party alive with heals and blessings.",
}

var _icon: TextureRect
var _class_label: Label
var _level_label: Label
var _gold_label: Label
var _title_label: Label
var _subtitle_label: Label
var _stat_labels := {}
var _item_labels: Array[Label] = []
var _activity_label: Label
var _hire_section: VBoxContainer
var _hire_class_label: Label
var _hire_desc_label: Label
var _hire_button: Button
var _sponsor_button: Button
## The inn recruit this panel is currently open for (Variant B), or null in
## the plain Variant A stat view.
var _recruit: Node


func _ready() -> void:
	add_to_group("hero_panel")
	hide()
	# The panel swallows clicks on itself; only clicks on the world close it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = PANEL_WIDTH
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(COLOR_BG, 0.95)
	panel.border_color = COLOR_BORDER
	panel.set_border_width_all(1)
	panel.content_margin_left = 10.0
	panel.content_margin_right = 10.0
	panel.content_margin_top = 8.0
	panel.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", panel)
	_build()
	# Keep the hire buttons' enabled state honest while the panel sits open.
	GameState.gold_changed.connect(func(_g: int) -> void: _refresh_hire_buttons())
	Roster.roster_changed.connect(_refresh_hire_buttons)


## Opens (or retargets) the panel for the roster member with this name.
func open(display_name: String) -> void:
	for member in Roster.members:
		if member["name"] == display_name:
			_recruit = null
			_hire_section.hide()
			_activity_label.text = "Wandering the town"
			_populate(member)
			_present()
			return


## Opens (or retargets) the panel in hire mode for an unhired inn recruit
## (mockup Variant B). Reads name/class/cost straight off the recruit node —
## there is no Roster entry yet.
func open_for_recruit(recruit: Node) -> void:
	_recruit = recruit
	_populate({
		"name": recruit.display_name,
		"class": recruit.adventurer_class,
		"level": 1,
	})
	_activity_label.text = "Looking for work"
	_hire_class_label.text = recruit.adventurer_class
	_hire_desc_label.text = CLASS_DESCRIPTIONS.get(recruit.adventurer_class, "")
	# BalanceNumbers "Hire + Sponsor": double the cost, and the recruit
	# arrives carrying their base cost as personal gold.
	_hire_button.text = "Hire (%d Gold)" % recruit.hire_cost
	_sponsor_button.text = "Hire and Sponsor (%d Gold)" % (recruit.hire_cost * 2)
	_refresh_hire_buttons()
	_hire_section.show()
	_present()


func _present() -> void:
	show()
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).floor()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide()


func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	header.add_child(left)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(SHEET_CELL_PX, SHEET_CELL_PX)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	left.add_child(_icon)
	_class_label = _label("", COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	left.add_child(_class_label)
	_level_label = _label("", COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	left.add_child(_level_label)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(center)
	_title_label = Label.new()
	_title_label.add_theme_font_override("font", TITLE_FONT)
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_title_label)
	_subtitle_label = _label("", COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(_subtitle_label)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	header.add_child(right)
	right.add_child(_label("Gold", COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_gold_label = _label("", COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	right.add_child(_gold_label)
	root.add_child(_separator())
	# Row 1: HP / Power / Morale; row 2: HP Regen / Morale Regen (mockup).
	var grid3 := GridContainer.new()
	grid3.columns = 3
	root.add_child(grid3)
	for key in ["hp", "power", "max_morale", "hp_regen", "morale_regen"]:
		_stat_labels[key] = _stat_cell(grid3)
	var grid2 := GridContainer.new()
	grid2.columns = 2
	root.add_child(grid2)
	for key in [
		"speed", "armor", "guard_pct", "evasion",
		"accuracy", "crit_pct", "crit_dmg_pct",
	]:
		_stat_labels[key] = _stat_cell(grid2)
	root.add_child(_label("Inventory", COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for _i in 3:
		var item := _label("", COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		_item_labels.append(item)
		root.add_child(item)
	root.add_child(_separator())
	_activity_label = _label(
		"Wandering the town", COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_activity_label)
	# Variant B hire section — hidden in the plain stat view.
	_hire_section = VBoxContainer.new()
	_hire_section.add_theme_constant_override("separation", 6)
	_hire_section.hide()
	root.add_child(_hire_section)
	_hire_section.add_child(_separator())
	_hire_class_label = _label("", COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hire_section.add_child(_hire_class_label)
	_hire_desc_label = _label("", COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_hire_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hire_section.add_child(_hire_desc_label)
	_hire_button = _hire_button_node(COLOR_GOLD)
	_hire_button.pressed.connect(_on_hire_pressed.bind(false))
	_hire_section.add_child(_hire_button)
	_sponsor_button = _hire_button_node(COLOR_TEXT)
	_sponsor_button.pressed.connect(_on_hire_pressed.bind(true))
	_hire_section.add_child(_sponsor_button)


func _populate(member: Dictionary) -> void:
	var adventurer_class: String = member["class"]
	var level: int = member["level"]
	var full_name: String = member["name"]
	# Roster names are "<first name> <epithet>"; the mockup header splits them
	# into title and capitalized subtitle ("Aldric" / "The Unyielding").
	var space := full_name.find(" ")
	_title_label.text = full_name if space < 0 else full_name.substr(0, space)
	var epithet := "" if space < 0 else full_name.substr(space + 1)
	if not epithet.is_empty():
		epithet = epithet[0].to_upper() + epithet.substr(1)
	_subtitle_label.text = epithet
	var atlas := AtlasTexture.new()
	atlas.atlas = VARIANT_SHEET
	var col: int = HiredAdventurerScript.CLASS_VARIANTS.get(adventurer_class, 0)
	atlas.region = Rect2(col * SHEET_CELL_PX, 0, SHEET_CELL_PX, SHEET_CELL_PX)
	_icon.texture = atlas
	_class_label.text = adventurer_class
	_level_label.text = "Lv %d" % level
	# GDD two-purse economy: fresh hires carry no personal gold yet; dungeon
	# drops will write a "gold" key onto the roster entry in a later slice.
	_gold_label.text = "%dg" % int(member.get("gold", 0))
	var stats := ClassStats.stats_at_level(adventurer_class, level)
	if stats.is_empty():
		return
	_stat_labels["hp"].text = "HP: %d" % int(stats["hp"])
	_stat_labels["power"].text = "Power: %d" % int(stats["power"])
	_stat_labels["max_morale"].text = "Morale: %d" % int(stats["max_morale"])
	_stat_labels["hp_regen"].text = "HP Regen: %d" % int(stats["hp_regen"])
	_stat_labels["morale_regen"].text = "Morale Regen: %d" % int(stats["morale_regen"])
	_stat_labels["speed"].text = "Speed: %d" % int(stats["speed"])
	_stat_labels["armor"].text = "Armor: %d" % int(stats["armor"])
	_stat_labels["guard_pct"].text = "Guard: %d%%" % int(stats["guard_pct"])
	_stat_labels["evasion"].text = "Evasion: %d%%" \
			% ClassStats.displayed_evasion_pct(stats["evasion"], level)
	_stat_labels["accuracy"].text = "Accuracy: %d%%" \
			% ClassStats.displayed_accuracy_pct(stats["accuracy"], level)
	_stat_labels["crit_pct"].text = "Crit: %d%%" % int(stats["crit_pct"])
	# The stats table shows no crit damage for a class that cannot crit.
	if stats["crit_pct"] > 0.0:
		_stat_labels["crit_dmg_pct"].text = "Crit Dmg: +%d%%" % int(stats["crit_dmg_pct"])
	else:
		_stat_labels["crit_dmg_pct"].text = "Crit Dmg: -"
	var items: Array = TIER0_ITEMS.get(adventurer_class, ["", "", ""])
	for i in 3:
		_item_labels[i].text = items[i]


func _on_hire_pressed(sponsored: bool) -> void:
	if _recruit == null or not is_instance_valid(_recruit):
		hide()
		return
	if _recruit.hire(sponsored):
		hide()


## Greys the hire buttons out while the roster is full or the treasury cannot
## cover each button's own price (mockup Variant B).
func _refresh_hire_buttons() -> void:
	if not visible or not _hire_section.visible:
		return
	if _recruit == null or not is_instance_valid(_recruit):
		# The recruit was hired via [E] (or despawned) under the open panel.
		hide()
		return
	var full: bool = Roster.is_full()
	_hire_button.disabled = full or not GameState.can_afford(_recruit.hire_cost)
	_sponsor_button.disabled = full or not GameState.can_afford(_recruit.hire_cost * 2)


func _hire_button_node(text_color: Color) -> Button:
	var button := Button.new()
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("34343e")
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(4.0)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("40404c")
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("1d1d24")
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("2b2b33")
	disabled.border_color = Color(COLOR_BORDER, 0.5)
	button.add_theme_stylebox_override("disabled", disabled)
	return button


func _label(text: String, color: Color, alignment: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment as HorizontalAlignment
	return label


func _stat_cell(grid: GridContainer) -> Label:
	var label := _label("", COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	return label


func _separator() -> ColorRect:
	var line := ColorRect.new()
	line.color = COLOR_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	return line
