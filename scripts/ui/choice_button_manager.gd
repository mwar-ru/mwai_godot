class_name ChoiceButtonManager
extends RefCounted

var choices_container: VBoxContainer
var quest: QuestEngine
var story: StoryController
var on_choice_selected: Callable
var on_save_quest_clicked: Callable
var on_reset_menu_clicked: Callable

func _init(container: VBoxContainer, p_quest: QuestEngine, p_story: StoryController, on_choice: Callable, on_save: Callable, on_reset: Callable) -> void:
	choices_container = container
	quest = p_quest
	story = p_story
	on_choice_selected = on_choice
	on_save_quest_clicked = on_save
	on_reset_menu_clicked = on_reset

func _create_choice_button(btn_text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = btn_text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 60)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.add_theme_stylebox_override("normal", GameStyle.create_choice_button_style())
	btn.pressed.connect(callback)
	return btn

func refresh(is_generating: bool) -> void:
	for child in choices_container.get_children():
		child.queue_free()

	if is_generating or story.current_mode == "chat" or not quest.is_game_active:
		choices_container.visible = false
		return

	choices_container.visible = true

	if quest.is_game_over:
		var save_b = _create_choice_button("💾 Сохранить сценарий в Downloads", on_save_quest_clicked)
		choices_container.add_child(save_b)

		var reset_b = _create_choice_button("🔄 В главное меню квестов", on_reset_menu_clicked)
		choices_container.add_child(reset_b)
		return

	var seen_labels: Array[String] = []

	if story.dynamic_game_choices.size() > 0:
		for c in story.dynamic_game_choices:
			var txt = c.get("text", "").strip_edges()
			if txt == "": continue
			var prev = c.get("preview", "").strip_edges()
			var label = "➤ " + txt + (" (" + prev + ")" if prev != "" else "")
			if not seen_labels.has(txt.to_lower()):
				seen_labels.append(txt.to_lower())
				var btn = _create_choice_button(label, func(): on_choice_selected.call(txt))
				choices_container.add_child(btn)

	for act in quest.get_scripted_actions():
		var act_txt = act.get("text", "").strip_edges()
		if act_txt == "" or seen_labels.has(act_txt.to_lower()):
			continue
		seen_labels.append(act_txt.to_lower())
		var prev = act.get("preview", "").strip_edges()
		var label = "🔍 " + act_txt + (" (" + prev + ")" if prev != "" else "")
		var btn = _create_choice_button(label, func(): on_choice_selected.call(act_txt))
		choices_container.add_child(btn)

	for conn in quest.get_connections():
		var move_txt = "Перейти в " + conn
		if seen_labels.has(move_txt.to_lower()):
			continue
		seen_labels.append(move_txt.to_lower())
		var label = "🚪 " + move_txt
		var btn = _create_choice_button(label, func(): on_choice_selected.call(move_txt))
		choices_container.add_child(btn)