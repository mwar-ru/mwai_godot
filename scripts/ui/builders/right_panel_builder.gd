class_name RightPanelBuilder
extends RefCounted

static func build(parent_split: HSplitContainer, r: Dictionary) -> void:
	var desktop_right_vbox = VBoxContainer.new()
	desktop_right_vbox.add_theme_constant_override("separation", 8)
	
	var map_panel = PanelContainer.new()
	map_panel.clip_contents = true
	var map_vbox = VBoxContainer.new()
	map_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var map_ctrl_hbox = HBoxContainer.new()
	map_ctrl_hbox.add_theme_constant_override("separation", 6)

	var btn_reset_view = Button.new()
	btn_reset_view.text = "Центр"
	btn_reset_view.custom_minimum_size = Vector2(85, 42)
	map_ctrl_hbox.add_child(btn_reset_view)
	r["btn_reset_view"] = btn_reset_view

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_ctrl_hbox.add_child(spacer)

	var btn_zoom_in = Button.new()
	btn_zoom_in.text = "+"
	btn_zoom_in.custom_minimum_size = Vector2(42, 42)
	map_ctrl_hbox.add_child(btn_zoom_in)
	r["btn_zoom_in"] = btn_zoom_in

	var btn_zoom_out = Button.new()
	btn_zoom_out.text = "−"
	btn_zoom_out.custom_minimum_size = Vector2(42, 42)
	map_ctrl_hbox.add_child(btn_zoom_out)
	r["btn_zoom_out"] = btn_zoom_out

	map_vbox.add_child(map_ctrl_hbox)

	var map_view = MapView.new()
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_vbox.add_child(map_view)
	map_panel.add_child(map_vbox)
	r["map_view"] = map_view
	r["map_panel"] = map_panel

	var char_panel = PanelContainer.new()
	var char_scroll = ScrollContainer.new()
	char_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	char_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	CommonStyle.enable_touch_scroll(char_scroll)

	var char_vbox = VBoxContainer.new()
	char_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_vbox.add_theme_constant_override("separation", 8)

	var stats_label = Label.new()
	stats_label.text = "❤️ HP: 100 | ⏳ Дни: 80"
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_vbox.add_child(stats_label)
	r["stats_label"] = stats_label

	var inv_title = Label.new()
	inv_title.text = "🎒 Снаряжение:"
	inv_title.add_theme_font_size_override("font_size", 17)
	char_vbox.add_child(inv_title)

	var inventory_container = HFlowContainer.new()
	inventory_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_vbox.add_child(inventory_container)
	r["inventory_container"] = inventory_container

	char_scroll.add_child(char_vbox)
	char_panel.add_child(char_scroll)
	r["char_panel"] = char_panel

	desktop_right_vbox.add_child(map_panel)
	desktop_right_vbox.add_child(char_panel)
	parent_split.add_child(desktop_right_vbox)
	
	r["desktop_right_vbox"] = desktop_right_vbox