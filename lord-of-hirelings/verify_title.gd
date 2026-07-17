extends Control

func _ready() -> void:
	# Root is a full-rect Control on purpose. Parenting main_menu.tscn to a Node2D
	# leaves its anchors resolving to a zero-size box, the backdrop TextureRect
	# gets no rect to cover, and it draws nothing -- indistinguishable from a
	# broken texture. change_scene_to_file is the other trap: it frees THIS node,
	# so the await below never resumes and the harness hangs instead of failing.
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await _shot(menu, "_verify_title_screen.png")

	# The confirmation panel is the semi-opaque thing that sits over the art, so
	# force it up and look at it rather than trusting that it reads.
	menu.get_node("CenterContainer").hide()
	var confirm: CenterContainer = menu.get_node("ConfirmPanel")
	confirm.get_node("Frame/Column/MessageLabel").text = \
		"Start a new campaign?\n\nThis overwrites your save:\nday 12, dungeon level 3."
	confirm.show()
	await _shot(menu, "_verify_title_confirm.png")
	get_tree().quit()


func _shot(_menu: Control, name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://../SourceArt/previews/" + name)
	print("VERIFY: captured ", name, " ", img.get_width(), "x", img.get_height())
