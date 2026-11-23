class_name NarrativeWelcomeBuilder
extends RefCounted

static func build(parent_vbox: VBoxContainer, r: Dictionary) -> void:
	var narrative_container = Control.new()
	narrative_container.custom_minimum_size = Vector2(0, 200)
	narrative_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	narrative_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r["narrative_container"] = narrative_container

	var narrative_box = RichTextLabel.new()
	narrative_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	narrative_box.bbcode_enabled = true
	narrative_box.scroll_following = true
	narrative_box.selection_enabled = true
	narrative_box.context_menu_enabled = true
	narrative_container.add_child(narrative_box)
	r["narrative_box"] = narrative_box

	var welcome_scroll = ScrollContainer.new()
	welcome_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	welcome_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	welcome_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	welcome_scroll.follow_focus = true
	CommonStyle.enable_touch_scroll(welcome_scroll)

	var welcome_panel = VBoxContainer.new()
	welcome_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	welcome_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	welcome_panel.add_theme_constant_override("separation", 8)
	welcome_scroll.add_child(welcome_panel)
	narrative_container.add_child(welcome_scroll)

	var w_title = Label.new()
	w_title.text = "🎮 Текстовый квест"
	w_title.modulate = Color("#4facfe")
	w_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w_title.add_theme_font_size_override("font_size", 20)
	welcome_panel.add_child(w_title)

	var w_desc = Label.new()
	w_desc.text = "Выберите заготовку или настройте мир:"
	w_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w_desc.add_theme_font_size_override("font_size", 14)
	welcome_panel.add_child(w_desc)

	var quest_preset_buttons_box = VBoxContainer.new()
	quest_preset_buttons_box.add_theme_constant_override("separation", 6)
	quest_preset_buttons_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	welcome_panel.add_child(quest_preset_buttons_box)
	r["quest_preset_buttons_box"] = quest_preset_buttons_box

	var setting_text_edit = TextEdit.new()
	setting_text_edit.custom_minimum_size = Vector2(0, 75)
	setting_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setting_text_edit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	setting_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	welcome_panel.add_child(setting_text_edit)
	r["setting_text_edit"] = setting_text_edit

	var params_panel = PanelContainer.new()
	var params_sb = StyleBoxFlat.new()
	params_sb.bg_color = Color("#111625")
	params_sb.border_color = Color("#222f49")
	params_sb.set_border_width_all(1)
	params_sb.set_corner_radius_all(6)
	params_sb.content_margin_left = 12
	params_sb.content_margin_right = 12
	params_sb.content_margin_top = 8
	params_sb.content_margin_bottom = 8
	params_panel.add_theme_stylebox_override("panel", params_sb)

	var params_vbox = VBoxContainer.new()
	params_vbox.add_theme_constant_override("separation", 8)

	var p_row1 = HBoxContainer.new()
	p_row1.add_theme_constant_override("separation", 16)

	var diff_box = HBoxContainer.new()
	diff_box.add_theme_constant_override("separation", 6)
	var diff_lbl = Label.new()
	diff_lbl.text = "Сложность:"
	diff_lbl.modulate = Color("#94a3b8")
	diff_box.add_child(diff_lbl)
	var diff_opt = OptionButton.new()
	diff_opt.add_item("Легкая")
	diff_opt.add_item("Средняя")
	diff_opt.add_item("Высокая")
	diff_opt.add_item("Хардкор")
	diff_opt.selected = 2
	diff_box.add_child(diff_opt)
	p_row1.add_child(diff_box)
	r["param_diff_opt"] = diff_opt

	var acts_box = HBoxContainer.new()
	acts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts_box.add_theme_constant_override("separation", 6)
	var acts_lbl = Label.new()
	acts_lbl.text = "Акты:"
	acts_lbl.modulate = Color("#94a3b8")
	acts_box.add_child(acts_lbl)

	var acts_input = LineEdit.new()
	acts_input.text = "3"
	acts_input.custom_minimum_size = Vector2(40, 32)
	acts_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	acts_box.add_child(acts_input)
	r["param_acts_input"] = acts_input

	var acts_slider = HSlider.new()
	acts_slider.min_value = 1
	acts_slider.max_value = 5
	acts_slider.value = 3
	acts_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts_box.add_child(acts_slider)
	r["param_acts_slider"] = acts_slider

	acts_slider.value_changed.connect(func(v): acts_input.text = str(int(v)))
	acts_input.text_changed.connect(func(txt):
		if txt.is_valid_int():
			acts_slider.value = clamp(int(txt), 1, 5)
	)
	p_row1.add_child(acts_box)
	params_vbox.add_child(p_row1)

	var p_row2 = HBoxContainer.new()
	p_row2.add_theme_constant_override("separation", 16)

	var loc_box = HBoxContainer.new()
	loc_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_box.add_theme_constant_override("separation", 6)
	var loc_lbl = Label.new()
	loc_lbl.text = "Локаций:"
	loc_lbl.modulate = Color("#94a3b8")
	loc_box.add_child(loc_lbl)

	var loc_input = LineEdit.new()
	loc_input.text = "5"
	loc_input.custom_minimum_size = Vector2(40, 32)
	loc_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	loc_box.add_child(loc_input)
	r["param_loc_input"] = loc_input

	var loc_slider = HSlider.new()
	loc_slider.min_value = 3
	loc_slider.max_value = 8
	loc_slider.value = 5
	loc_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_box.add_child(loc_slider)
	r["param_loc_slider"] = loc_slider

	loc_slider.value_changed.connect(func(v): loc_input.text = str(int(v)))
	loc_input.text_changed.connect(func(txt):
		if txt.is_valid_int():
			loc_slider.value = clamp(int(txt), 3, 8)
	)
	p_row2.add_child(loc_box)

	var permadeath_box = HBoxContainer.new()
	permadeath_box.add_theme_constant_override("separation", 8)
	var permadeath_lbl = Label.new()
	permadeath_lbl.text = "Пермасмерть:"
	permadeath_lbl.modulate = Color("#94a3b8")
	permadeath_box.add_child(permadeath_lbl)
	var permadeath_check = CheckButton.new()
	permadeath_check.button_pressed = true
	permadeath_box.add_child(permadeath_check)
	p_row2.add_child(permadeath_box)
	r["param_permadeath_check"] = permadeath_check

	params_vbox.add_child(p_row2)
	params_panel.add_child(params_vbox)
	welcome_panel.add_child(params_panel)
	r["params_panel"] = params_panel

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var start_gen_btn = Button.new()
	start_gen_btn.text = "🚀 Сгенерировать кампанию"
	start_gen_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # <--- ПЕРЕНОС СТРОКИ
	start_gen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_gen_btn.custom_minimum_size = Vector2(0, 42)
	btn_row.add_child(start_gen_btn)
	r["start_gen_btn"] = start_gen_btn

	var load_file_btn = Button.new()
	load_file_btn.text = "📁 Загрузить файл"
	load_file_btn.autowrap_mode = TextServer.AUTOWRAP_OFF # <--- OFF ПЕРЕНОС СТРОКИ
	load_file_btn.custom_minimum_size = Vector2(130, 42)
	btn_row.add_child(load_file_btn)
	r["load_file_btn"] = load_file_btn

	welcome_panel.add_child(btn_row)
	r["btn_row"] = btn_row
	r["welcome_panel"] = welcome_panel
	r["welcome_scroll"] = welcome_scroll

	parent_vbox.add_child(narrative_container)