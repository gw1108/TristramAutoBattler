extends Control
## Title screen (GDD "Title screen and campaign save"). New Game always shows;
## Continue and Manage Save appear only once the one campaign autosave exists.
##
## There are no save slots — the game intentionally has one replaceable campaign
## autosave — so Manage Save is a readout of that single file plus the one
## destructive thing that can be done to it. Both doors that destroy a campaign
## (New Game over an existing save, Delete Save) go through the same
## confirmation.

const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"

## What the pending confirmation will do if the player takes it. Both outcomes
## end the saved campaign, which is why neither runs off a bare press (GDD).
enum Confirm { NONE, NEW_GAME, DELETE_SAVE }

@onready var _menu: CenterContainer = $CenterContainer
@onready var _new_game_button: Button = $CenterContainer/MenuColumn/NewGameButton
@onready var _continue_button: Button = $CenterContainer/MenuColumn/ContinueButton
@onready var _manage_button: Button = $CenterContainer/MenuColumn/ManageSaveButton

@onready var _manage_panel: CenterContainer = $ManagePanel
@onready var _manage_details: Label = $ManagePanel/Frame/Column/DetailsLabel
@onready var _delete_button: Button = $ManagePanel/Frame/Column/DeleteButton
@onready var _manage_back_button: Button = $ManagePanel/Frame/Column/BackButton

@onready var _confirm_panel: CenterContainer = $ConfirmPanel
@onready var _confirm_label: Label = $ConfirmPanel/Frame/Column/MessageLabel
@onready var _confirm_button: Button = $ConfirmPanel/Frame/Column/ButtonRow/ConfirmButton
@onready var _cancel_button: Button = $ConfirmPanel/Frame/Column/ButtonRow/CancelButton

var _confirming := Confirm.NONE


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_manage_button.pressed.connect(_on_manage_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_manage_back_button.pressed.connect(_show_menu)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_show_menu)
	_show_menu()


## Back to the three buttons, with the save-only two hidden when there is no
## autosave to continue or manage (GDD). Re-read on every return rather than
## cached once, because Delete Save comes back through here.
func _show_menu() -> void:
	_confirming = Confirm.NONE
	var has_save := SaveGame.has_save()
	_continue_button.visible = has_save
	_manage_button.visible = has_save
	_manage_panel.hide()
	_confirm_panel.hide()
	_menu.show()
	# Launching resumes from the most recent autosave (GDD), so Continue is the
	# default action whenever there is one to resume.
	(_continue_button if has_save else _new_game_button).grab_focus()


func _on_continue_pressed() -> void:
	if SaveGame.load_game().is_empty():
		# The file went missing or unreadable between this menu drawing itself
		# and the press. Back to the menu — which will no longer offer Continue —
		# rather than dropping into a half-restored town.
		_show_menu()
		return
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _on_new_game_pressed() -> void:
	if not SaveGame.has_save():
		_start_new_game()
		return
	var header := SaveGame.read_header()
	_ask(Confirm.NEW_GAME, "Start a new campaign?\n\nThis overwrites your save:\nday %d, dungeon level %d." % [
		int(header.get("day", 0)), int(header.get("dungeon_level", 1))])


## The GDD's stated reason for the confirmation is that New Game overwrites the
## save, so it does exactly that up front rather than leaving the old campaign
## sitting there until the new one's first autosave: a player who confirms and
## then quits before entering the dungeon has already abandoned it, and Continue
## must not offer it back to them.
func _start_new_game() -> void:
	SaveGame.delete_save()
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


## Manage Save (GDD): the current day, dungeon level, and most recent autosave
## point of the one save, and the one destructive thing that can be done to it.
func _on_manage_pressed() -> void:
	var header := SaveGame.read_header()
	if header.is_empty():
		_show_menu()
		return
	_manage_details.text = "Day %d\nDungeon level %d\nSaved at: %s" % [
		int(header.get("day", 0)),
		int(header.get("dungeon_level", 1)),
		SaveGame.point_label(String(header.get("point", ""))),
	]
	_menu.hide()
	_confirm_panel.hide()
	_manage_panel.show()
	_manage_back_button.grab_focus()


func _on_delete_pressed() -> void:
	_ask(Confirm.DELETE_SAVE,
		"Delete your campaign save?\n\nThis cannot be undone.")


func _ask(action: Confirm, message: String) -> void:
	_confirming = action
	_confirm_label.text = message
	_menu.hide()
	_manage_panel.hide()
	_confirm_panel.show()
	# Cancel takes the focus, not Confirm: both answers here end a campaign, so
	# a stray Enter must not be one of them.
	_cancel_button.grab_focus()


func _on_confirm_pressed() -> void:
	var action := _confirming
	_confirming = Confirm.NONE
	match action:
		Confirm.NEW_GAME:
			_start_new_game()
		Confirm.DELETE_SAVE:
			SaveGame.delete_save()
			_show_menu()
		_:
			_show_menu()
