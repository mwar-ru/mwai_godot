class_name SmartBarBuilder
extends RefCounted

static func build(parent_vbox: VBoxContainer, r: Dictionary) -> void:
	var smart_bar_panel = PanelContainer.new()
	var sb_row = HBoxContainer.new()
	sb_row.add_theme_constant_override("separation", 8)

	var mode_chat_btn = Button.new()
	mode_chat_btn.text = "💬 Чат"
	mode_chat_btn.custom_minimum_size = Vector2(110, 48)
	sb_row.add_child(mode_chat_btn)
	r["mode_chat_btn"] = mode_chat_btn

	var mode_game_btn = Button.new()
	mode_game_btn.text = "🎮 Игра"
	mode_game_btn.custom_minimum_size = Vector2(110, 48)
	sb_row.add_child(mode_game_btn)
	r["mode_game_btn"] = mode_game_btn

	var smart_bar_button = Button.new()
	smart_bar_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smart_bar_button.size_flags_stretch_ratio = 1.0
	smart_bar_button.custom_minimum_size = Vector2(180, 54)
	smart_bar_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	smart_bar_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	sb_row.add_child(smart_bar_button)
	r["smart_bar_button"] = smart_bar_button

	var sb_bg_status = Label.new()
	sb_bg_status.modulate = Color("#38bdf8")
	sb_bg_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb_bg_status.size_flags_stretch_ratio = 1.0
	sb_bg_status.custom_minimum_size = Vector2(180, 54)
	sb_bg_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sb_bg_status.visible = false
	sb_row.add_child(sb_bg_status)
	r["sb_bg_status"] = sb_bg_status

	smart_bar_panel.add_child(sb_row)
	parent_vbox.add_child(smart_bar_panel)
	r["smart_bar_panel"] = smart_bar_panel