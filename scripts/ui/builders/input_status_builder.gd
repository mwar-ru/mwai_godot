class_name InputStatusBuilder
extends RefCounted

static func build(parent_vbox: VBoxContainer, r: Dictionary) -> void:
	var live_status_hbox = HBoxContainer.new()
	live_status_hbox.add_theme_constant_override("separation", 8)
	live_status_hbox.custom_minimum_size = Vector2(0, 40)

	var live_status_label = Label.new()
	live_status_label.text = "🟢 Модель ожидает ваше действие"
	live_status_label.modulate = Color("#94a3b8")
	live_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	live_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live_status_label.add_theme_font_size_override("font_size", 16)
	live_status_hbox.add_child(live_status_label)
	r["live_status_label"] = live_status_label

	var live_thinking_toggle_btn = Button.new()
	live_thinking_toggle_btn.text = "👁️ Размышления модели"
	live_thinking_toggle_btn.visible = false
	live_thinking_toggle_btn.custom_minimum_size = Vector2(190, 38)
	live_status_hbox.add_child(live_thinking_toggle_btn)
	r["live_thinking_toggle_btn"] = live_thinking_toggle_btn

	var copy_all_button = Button.new()
	copy_all_button.text = "📋 Копировать"
	copy_all_button.custom_minimum_size = Vector2(130, 38)
	live_status_hbox.add_child(copy_all_button)
	r["copy_all_button"] = copy_all_button

	parent_vbox.add_child(live_status_hbox)
	r["live_status_hbox"] = live_status_hbox

	var live_thinking_box = RichTextLabel.new()
	live_thinking_box.custom_minimum_size = Vector2(0, 480)
	live_thinking_box.visible = false
	live_thinking_box.scroll_following = true
	live_thinking_box.modulate = Color("#94a3b8")
	live_thinking_box.add_theme_font_size_override("normal_font_size", 16)
	CommonStyle.enable_touch_scroll(live_thinking_box)
	parent_vbox.add_child(live_thinking_box)
	r["live_thinking_box"] = live_thinking_box

	var choices_container = VBoxContainer.new()
	choices_container.add_theme_constant_override("separation", 8)
	parent_vbox.add_child(choices_container)
	r["choices_container"] = choices_container

	var input_hbox = HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", 8)

	var input_text_edit = TextEdit.new()
	input_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_text_edit.custom_minimum_size = Vector2(0, 56)
	input_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input_hbox.add_child(input_text_edit)
	r["input_text_edit"] = input_text_edit

	var fast_mode_btn = Button.new()
	fast_mode_btn.text = "🧠 С мыслями"
	fast_mode_btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	fast_mode_btn.custom_minimum_size = Vector2(115, 48)
	input_hbox.add_child(fast_mode_btn)
	r["fast_mode_btn"] = fast_mode_btn

	var send_button = Button.new()
	send_button.text = "➤"
	send_button.custom_minimum_size = Vector2(56, 56)
	input_hbox.add_child(send_button)
	r["send_button"] = send_button

	parent_vbox.add_child(input_hbox)