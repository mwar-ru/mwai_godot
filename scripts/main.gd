extends Control

var api: ApiClient
var quest: QuestEngine
var story: StoryController
var settings_drawer: SettingsDrawer
var session_manager: SessionManager
var choice_manager: ChoiceButtonManager
var layout: LayoutController

var ui: Dictionary = {}
var sandbox_manager: SandboxManager
var is_generating: bool = false
var is_bg_expanding: bool = false
var active_pending_task: Dictionary = {}
var _has_virtual_keyboard: bool = false
var _last_kb_height: int = 0

func _ready() -> void:
	_has_virtual_keyboard = DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)

	api = ApiClient.new()
	quest = QuestEngine.new()
	story = StoryController.new(quest, api)
	theme = CommonStyle.create_base_theme()

	ui = UIBuilder.build(self)
	layout = LayoutController.new(self, ui)
	ui["welcome_scroll"].resized.connect(layout.update_setting_input_height)

	# Инициализация песочницы мини-игр
	sandbox_manager = SandboxManager.new()
	add_child(sandbox_manager)
	sandbox_manager.setup(self, ui, api)
	sandbox_manager.sandbox_closed.connect(func():
		layout.apply_mode_visibility(story.current_mode, is_generating, quest.is_game_active)
	)

	choice_manager = ChoiceButtonManager.new(
		ui["choices_container"], quest, story,
		handle_choice,
		_on_save_quest_clicked,
		_on_clear_mode_pressed
	)

	session_manager = SessionManager.new(self)
	session_manager.quest_blueprint_loaded.connect(_on_quest_blueprint_loaded)
	session_manager.session_loaded.connect(_on_session_data_loaded)
	session_manager.sandbox_game_loaded.connect(_on_sandbox_game_loaded)
	session_manager.toast_requested.connect(show_toast)

	settings_drawer = SettingsDrawer.new()
	add_child(settings_drawer)
	settings_drawer.setup(api)
	settings_drawer.settings_changed.connect(update_smartbar_ui)
	settings_drawer.clear_requested.connect(_on_clear_mode_pressed)
	settings_drawer.models_loaded.connect(_on_models_loaded)
	settings_drawer.export_session_requested.connect(func(): session_manager.export_session(story.current_mode, story.get_active_log(), quest, api))
	settings_drawer.import_session_requested.connect(session_manager.open_session_picker)

	_bind_events()
	_update_fast_mode_btn_ui()

	var initial_mode = "chat"
	var pending_to_resume = {}

	if session_manager.has_auto_save():
		var saved_data = session_manager.load_auto_save()
		_restore_session_state(saved_data)
		initial_mode = saved_data.get("mode", "chat")
		if saved_data.has("pending_generation") and saved_data["pending_generation"] is Dictionary:
			pending_to_resume = saved_data["pending_generation"].duplicate()

	set_mode(initial_mode)
	_on_viewport_resized()

	if pending_to_resume.size() > 0:
		call_deferred("_resume_pending_generation", pending_to_resume)

func _bind_events() -> void:
	api.token_received.connect(_on_token_received)
	api.thinking_token_received.connect(_on_thinking_token_received)
	api.stream_status_changed.connect(_on_stream_status_changed)
	api.stream_finished.connect(_on_stream_finished)
	api.stream_error.connect(_on_stream_error)
	get_viewport().size_changed.connect(_on_viewport_resized)

	story.ui_update_requested.connect(func(): update_smartbar_ui(); rebuild_narrative(); _trigger_auto_save())
	story.story_entry_added.connect(func(): rebuild_narrative(); _trigger_auto_save())
	story.choices_changed.connect(func(): refresh_choices(); _trigger_auto_save())

	story.bg_expansion_state_changed.connect(func(running: bool, msg: String, _tok: int, _elapsed: float):
		is_bg_expanding = running
		if running:
			ui["live_status_label"].text = msg
			ui["live_status_label"].modulate = Color("#38bdf8")
		elif not is_generating:
			ui["live_status_label"].text = "🟢 Модель ожидает ваше действие"
			ui["live_status_label"].modulate = Color("#94a3b8")
			ui["live_thinking_toggle_btn"].visible = false
	)

	ui["mode_chat_btn"].pressed.connect(func(): set_mode("chat"))
	ui["mode_game_btn"].pressed.connect(func(): set_mode("game"))
	ui["smart_bar_button"].pressed.connect(func(): settings_drawer.toggle_below(ui["smart_bar_panel"], ui["smart_bar_button"]))
	ui["start_gen_btn"].pressed.connect(_on_start_generate_campaign_pressed)
	ui["load_file_btn"].pressed.connect(func(): session_manager.open_quest_picker())
	ui["copy_all_button"].pressed.connect(_on_copy_all_pressed)
	ui["fast_mode_btn"].pressed.connect(_on_fast_mode_toggled)
	ui["send_button"].pressed.connect(_submit_input)

	ui["input_text_edit"].gui_input.connect(_on_input_gui_input)
	ui["input_text_edit"].text_changed.connect(_on_input_text_changed)
	ui["narrative_box"].meta_clicked.connect(_on_meta_clicked)
	ui["live_thinking_toggle_btn"].pressed.connect(func(): ui["live_thinking_box"].visible = !ui["live_thinking_box"].visible)

	ui["btn_reset_view"].pressed.connect(func(): ui["map_view"].reset_view())
	ui["btn_zoom_in"].pressed.connect(func(): ui["map_view"].zoom_in())
	ui["btn_zoom_out"].pressed.connect(func(): ui["map_view"].zoom_out())
	ui["map_view"].location_selected.connect(func(loc): handle_choice("Перейти в " + loc))

	for p_key in quest.presets:
		var b = Button.new()
		var p_data = quest.presets[p_key]
		b.text = "📜 " + p_data["name"]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # <--- ПЕРЕНОС ДЛЯ ДЛИННЫХ НАЗВАНИЙ
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(func(): _apply_preset_to_ui(p_data))
		ui["quest_preset_buttons_box"].add_child(b)

	_apply_preset_to_ui(quest.presets["prison"])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_trigger_auto_save()

func _process(_delta: float) -> void:
	# Вызываем только если платформа реально поддерживает экранную клавиатуру (Android/iOS)
	if _has_virtual_keyboard:
		var kb_h = DisplayServer.virtual_keyboard_get_height()
		if kb_h != _last_kb_height:
			_last_kb_height = kb_h
			_on_viewport_resized()

	if is_generating or is_bg_expanding:
		var pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))
		if ui.has("live_status_label"):
			ui["live_status_label"].modulate.a = pulse
	else:
		if ui.has("live_status_label"):
			ui["live_status_label"].modulate.a = 1.0

func _trigger_auto_save() -> void:
	if session_manager:
		session_manager.auto_save(story.current_mode, story, quest, api, active_pending_task)

func _restore_session_state(data: Dictionary) -> void:
	if data.has("chat_story_log") and data["chat_story_log"] is Array and data["chat_story_log"].size() > 0:
		story.chat_story_log = data["chat_story_log"]
	if data.has("game_story_log") and data["game_story_log"] is Array:
		story.game_story_log = data["game_story_log"]
	if data.has("dynamic_game_choices") and data["dynamic_game_choices"] is Array:
		story.dynamic_game_choices = data["dynamic_game_choices"]

	if data.has("tokens"):
		var tok = data["tokens"]
		story.game_tokens = tok.get("game_tokens", 0)
		story.chat_tokens = tok.get("chat_tokens", 0)
		story.game_context_tokens = tok.get("game_context_tokens", 0)
		story.chat_context_tokens = tok.get("chat_context_tokens", 0)

	if data.has("gameState"):
		var gs = data["gameState"]
		quest.is_game_active = gs.get("active", false)
		quest.is_game_over = gs.get("is_game_over", false)
		quest.current_location = gs.get("currentLocation", "Камера")
		quest.inventory = gs.get("inventory", [])
		quest.stats = gs.get("stats", {})
		quest.world_graph = gs.get("world_graph", {})
		quest.visited_locations = gs.get("visited", [])
		quest.revealed_locations = gs.get("revealed", [])
		quest.active_campaign_title = gs.get("title", "Квест")
		quest.active_setting_text = gs.get("setting", "")
		quest.current_act = gs.get("act", 1)

		update_character_ui()
		if ui.has("map_view"):
			ui["map_view"].root_loc = quest.current_location
			ui["map_view"].update_data(quest.world_graph, quest.current_location, quest.visited_locations, quest.revealed_locations)

	update_smartbar_ui()
	rebuild_narrative()

func _resume_pending_generation(task: Dictionary) -> void:
	var task_type = task.get("type", "")
	var content = task.get("content", "")
	active_pending_task.clear()
	_trigger_auto_save()

	show_toast("🔄 Восстановление прерванной генерации...")
	match task_type:
		"campaign":
			if ui.has("setting_text_edit") and content != "":
				ui["setting_text_edit"].text = content
			_on_start_generate_campaign_pressed()
		"game_action":
			set_mode("game")
			handle_choice(content)
		"chat_message":
			set_mode("chat")
			ui["narrative_box"].append_text("[color=#38bdf8][font_size=%d]Вы: %s[/font_size][/color]\n\n" % [layout.current_font_size + 1, content])
			set_ui_locked(true); ui["live_thinking_box"].clear()
			active_pending_task = {"type": "chat_message", "content": content}
			_trigger_auto_save()
			story.send_chat_message(content, get_tree())

func _apply_preset_to_ui(preset_data: Dictionary) -> void:
	if ui.has("setting_text_edit"):
		ui["setting_text_edit"].text = preset_data.get("setting", "")

	var p = preset_data.get("params", {})
	if ui.has("param_diff_opt"):
		match p.get("difficulty", "hard"):
			"easy": ui["param_diff_opt"].selected = 0
			"medium": ui["param_diff_opt"].selected = 1
			"hard": ui["param_diff_opt"].selected = 2
			"nightmare": ui["param_diff_opt"].selected = 3

	var acts_val = p.get("acts", 3)
	if ui.has("param_acts_input"):
		ui["param_acts_input"].text = str(acts_val)
	if ui.has("param_acts_slider"):
		ui["param_acts_slider"].value = clamp(acts_val, 1, 5)

	var locs_val = p.get("locations_count", 5)
	if ui.has("param_loc_input"):
		ui["param_loc_input"].text = str(locs_val)
	if ui.has("param_loc_slider"):
		ui["param_loc_slider"].value = clamp(locs_val, 3, 8)

	if ui.has("param_permadeath_check"):
		ui["param_permadeath_check"].button_pressed = p.get("permadeath", true)

func _collect_scenario_params_from_ui() -> void:
	if not ui.has("param_diff_opt"): return
	var diff_map = ["easy", "medium", "hard", "nightmare"]
	quest.scenario_params["difficulty"] = diff_map[ui["param_diff_opt"].selected]

	if ui.has("param_acts_input") and ui["param_acts_input"].text.is_valid_int():
		quest.scenario_params["acts"] = max(1, int(ui["param_acts_input"].text))
	else:
		quest.scenario_params["acts"] = int(ui["param_acts_slider"].value)

	if ui.has("param_loc_input") and ui["param_loc_input"].text.is_valid_int():
		quest.scenario_params["locations_count"] = max(2, int(ui["param_loc_input"].text))
	else:
		quest.scenario_params["locations_count"] = int(ui["param_loc_slider"].value)

	quest.scenario_params["permadeath"] = ui["param_permadeath_check"].button_pressed

func _on_sandbox_game_loaded(data: Dictionary) -> void:
	set_mode("game")
	sandbox_manager.load_game_from_data(data)
	show_toast("🎮 Мини-игра '%s' загружена!" % data.get("title", "Игра"))
	_trigger_auto_save()

func _on_start_generate_campaign_pressed() -> void:
	var s = ui["setting_text_edit"].text.strip_edges()
	if s == "": return
	_collect_scenario_params_from_ui()
	if ui.has("welcome_scroll"): ui["welcome_scroll"].visible = false
	if ui.has("welcome_panel"): ui["welcome_panel"].visible = false
	if ui.has("narrative_box"): ui["narrative_box"].visible = true
	ui["live_status_label"].text = "🚀 Создание кампании и карты мира..."
	ui["live_status_label"].modulate = Color("#38bdf8")
	set_ui_locked(true)
	active_pending_task = {"type": "campaign", "content": s}
	_trigger_auto_save()
	story.start_campaign_generation(s, get_tree())

func _on_quest_blueprint_loaded(json: Dictionary) -> void:
	quest.apply_generated_blueprint(json, json.get("title", "Загруженный квест"))
	if ui.has("welcome_scroll"): ui["welcome_scroll"].visible = false
	if ui.has("welcome_panel"): ui["welcome_panel"].visible = false
	if ui.has("narrative_box"): ui["narrative_box"].visible = true
	story.game_story_log.clear()
	story.dynamic_game_choices = quest.generate_location_choices()
	story.add_story_entry("", quest.world_graph[quest.current_location].get("desc", "Приключение начинается..."))
	update_character_ui()
	ui["map_view"].root_loc = quest.current_location
	ui["map_view"].update_data(quest.world_graph, quest.current_location, quest.visited_locations, quest.revealed_locations)
	ui["choices_container"].visible = true
	rebuild_narrative()
	_trigger_auto_save()

func _on_session_data_loaded(json: Dictionary) -> void:
	var cfg = json.get("config", {})
	api.base_url = cfg.get("address", api.base_url)
	api.provider = cfg.get("provider", api.provider)
	api.auth_type = cfg.get("authType", api.auth_type)
	api.auth_token = cfg.get("token", api.auth_token)
	api.model_name = cfg.get("model", api.model_name)

	if json.has("mode"): set_mode(json["mode"])
	if json.has("messages"):
		if story.current_mode == "game": story.game_story_log = json["messages"]
		else: story.chat_story_log = json["messages"]

	if json.has("gameState"):
		var gs = json["gameState"]
		quest.is_game_active = gs.get("active", false)
		quest.current_location = gs.get("currentLocation", "Камера")
		quest.inventory = gs.get("inventory", [])
		quest.stats = gs.get("stats", {})
		quest.world_graph = gs.get("world_graph", {})
		quest.visited_locations = gs.get("visited", [])
		quest.revealed_locations = gs.get("revealed", [])
		quest.active_campaign_title = gs.get("title", "Квест")
		update_character_ui()
		ui["map_view"].root_loc = quest.current_location
		ui["map_view"].update_data(quest.world_graph, quest.current_location, quest.visited_locations, quest.revealed_locations)
		ui["choices_container"].visible = true

	settings_drawer.save_settings()
	settings_drawer.build_ui()
	update_smartbar_ui()
	rebuild_narrative()
	_trigger_auto_save()
	show_toast("Сессия успешно загружена!")

func _on_input_text_changed() -> void:
	var lines = ui["input_text_edit"].get_line_count()
	var font = ui["input_text_edit"].get_theme_font("font")
	var font_sz = ui["input_text_edit"].get_theme_font_size("font_size")
	var line_h = font.get_height(font_sz) if font else 24.0
	ui["input_text_edit"].custom_minimum_size.y = clamp(clamp(lines, 1, 6) * line_h + 24.0, 56.0, 160.0)

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not (event.shift_pressed or event.ctrl_pressed):
				accept_event()
				_submit_input()

func _submit_input() -> void:
	var text = ui["input_text_edit"].text.strip_edges()
	if text == "": return

	if is_generating:
		if story.current_mode == "chat":
			story.chat_queue.append(text)
			ui["input_text_edit"].text = ""; _on_input_text_changed()
			show_toast("Сообщение добавлено в очередь (%d)" % story.chat_queue.size())
		return

	ui["input_text_edit"].text = ""; _on_input_text_changed()

	if story.current_mode == "game":
		if not quest.is_game_active and not sandbox_manager.is_active:
			# Квест ещё не начат — пользователь попросил создать мини-игру!
			set_ui_locked(true)
			ui["live_status_label"].text = "🚀 Генерация игры по запросу..."
			ui["live_status_label"].modulate = Color("#38bdf8")
			sandbox_manager.start_new_game(text)
		elif sandbox_manager.is_active:
			# Песочница уже открыта — пользователь вносит правки в код игры!
			set_ui_locked(true)
			ui["live_status_label"].text = "⚙️ Применение правок к игре..."
			ui["live_status_label"].modulate = Color("#38bdf8")
			sandbox_manager.edit_game(text)
		else:
			# Идет обычный текстовый квест
			handle_choice(text)
	else:
		# Обычный чат
		ui["narrative_box"].append_text("[color=#38bdf8][font_size=%d]Вы: %s[/font_size][/color]\n\n" % [layout.current_font_size + 1, text])
		set_ui_locked(true); ui["live_thinking_box"].clear()
		active_pending_task = {"type": "chat_message", "content": text}
		_trigger_auto_save()
		story.send_chat_message(text, get_tree())

func handle_choice(choice_text: String) -> void:
	if is_generating or quest.is_game_over: return

	var act_res = quest.execute_action(choice_text)
	if act_res.get("found", false):
		var narr = act_res["narration"]
		if act_res.get("is_ending", false):
			narr += GameStyle.format_game_over(act_res.get("victory", false), "Цель кампании достигнута!" if act_res.get("victory", false) else "Ваша история завершилась поражением.")
		story.add_story_entry(choice_text, narr, "", {}, "🤖 Скрипт | 0.0s | 0 tok", api.model_name, "офлайн")
		update_character_ui()
		story.dynamic_game_choices = quest.generate_location_choices()
		ui["map_view"].update_data(quest.world_graph, quest.current_location, quest.visited_locations, quest.revealed_locations)
		ui["choices_container"].visible = true
		rebuild_narrative()
		story.check_and_trigger_world_expansion(get_tree())
		_trigger_auto_save()
		return

	if choice_text.begins_with("Перейти в ") or quest.get_connections().has(choice_text):
		var target_loc = choice_text.replace("Перейти в ", "").strip_edges()
		var move_res = quest.try_move(target_loc)
		var narr = move_res.get("narration", "Вы переходите в [локация: " + target_loc + "].") if move_res is Dictionary else ""
		if move_res is Dictionary and move_res.get("is_ending", false):
			narr += GameStyle.format_game_over(move_res.get("victory", false), "Цель кампании достигнута!" if move_res.get("victory", false) else "Ваша история завершилась поражением.")
		story.add_story_entry(choice_text, narr, "", {}, "🤖 Топология | 0.0s | 0 tok", api.model_name, "офлайн")
		update_character_ui()
		story.dynamic_game_choices = quest.generate_location_choices()
		ui["map_view"].update_data(quest.world_graph, quest.current_location, quest.visited_locations, quest.revealed_locations)
		ui["choices_container"].visible = true
		rebuild_narrative()
		story.check_and_trigger_world_expansion(get_tree())
		_trigger_auto_save()
		return

	ui["narrative_box"].append_text("[color=#38bdf8][font_size=%d]➤ %s[/font_size][/color]\n\n" % [layout.current_font_size + 1, choice_text])
	set_ui_locked(true); ui["live_thinking_box"].clear()
	active_pending_task = {"type": "game_action", "content": choice_text}
	_trigger_auto_save()
	story.send_player_choice(choice_text, get_tree())

func _on_stream_finished(narrative: String, thinking: String, stats_data: Dictionary) -> void:
	active_pending_task.clear()

	# Если ответ предназначался для генератора мини-игр песочницы
	if sandbox_manager and sandbox_manager.is_generating_game:
		sandbox_manager.on_stream_completed(narrative, thinking, stats_data)
		set_ui_locked(false)
		update_smartbar_ui()
		return

	var result = story.handle_stream_completed(narrative, thinking, stats_data, ui["setting_text_edit"].text)
	update_smartbar_ui()

	if result.has("blueprint_applied"):
		update_character_ui()
		ui["map_view"].root_loc = result["start_loc"]
		ui["map_view"].update_data(quest.world_graph, quest.current_location, quest.visited_locations, quest.revealed_locations)
		if ui.has("welcome_scroll"): ui["welcome_scroll"].visible = false
		if ui.has("welcome_panel"): ui["welcome_panel"].visible = false
		if ui.has("narrative_box"): ui["narrative_box"].visible = true
		if ui.has("choices_container"): ui["choices_container"].visible = true
		set_ui_locked(false)
		refresh_choices()
		_trigger_auto_save()
		return

	if result.has("turn_applied"):
		update_character_ui()
		ui["map_view"].update_data(quest.world_graph, quest.current_location, quest.visited_locations, quest.revealed_locations)
		ui["choices_container"].visible = true
		set_ui_locked(false)
		refresh_choices()
		story.check_and_trigger_world_expansion(get_tree())
		_trigger_auto_save()
		return

	set_ui_locked(false)
	_trigger_auto_save()
	if story.current_mode == "chat" and story.chat_queue.size() > 0:
		var next_text = story.chat_queue.pop_front()
		ui["input_text_edit"].text = next_text
		_submit_input()

func _on_stream_error(msg: String) -> void:
	active_pending_task.clear()

	if sandbox_manager and sandbox_manager.is_generating_game:
		sandbox_manager.on_stream_error(msg)
		set_ui_locked(false)
		return

	story.add_story_entry(story.pending_user_action, "[color=#f87171]❌ Ошибка обращения к модели:\n" + msg + "[/color]")
	story.pending_user_action = ""
	set_ui_locked(false)
	_trigger_auto_save()

func _on_models_loaded(count: int, err: String) -> void:
	if count > 0:
		story.add_story_entry("", "[color=#38bdf8]🟢 Список моделей обновлен (%d шт.)[/color]" % count)
	else:
		story.add_story_entry("", "[color=#f87171]❌ Ошибка моделей от %s:\n%s[/color]" % [api.base_url, err])

func _on_clear_mode_pressed() -> void:
	active_pending_task.clear()
	story.clear_current_log()
	if story.current_mode == "game":
		if ui.has("welcome_scroll"): ui["welcome_scroll"].visible = true
		if ui.has("welcome_panel"): ui["welcome_panel"].visible = true
		if ui.has("narrative_box"): ui["narrative_box"].visible = false
		if ui.has("choices_container"): ui["choices_container"].visible = false
	_trigger_auto_save()

func _on_save_quest_clicked() -> void:
	var p = quest.export_quest_file()
	if p != "": story.add_story_entry("", "[color=#2ecc71]💾 Сценарий сохранён в файл:\n%s[/color]" % p)

func update_smartbar_ui() -> void:
	var mode_tok = story.game_tokens if story.current_mode == "game" else story.chat_tokens
	var ctx_tok = story.game_context_tokens if story.current_mode == "game" else story.chat_context_tokens
	ui["smart_bar_button"].text = "⚙️ %s | 🔢 %d tok | 🧠 Context: %d/32k" % [api.model_name, mode_tok, ctx_tok]

func _on_viewport_resized() -> void:
	if _has_virtual_keyboard:
		var kb_height: int = DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			ui["root_margin"].add_theme_constant_override("margin_bottom", kb_height + 8)
		else:
			ui["root_margin"].add_theme_constant_override("margin_bottom", 8)
	else:
		ui["root_margin"].add_theme_constant_override("margin_bottom", 8)

	layout.update_layout(story.current_mode, quest.is_game_active, is_generating, quest, settings_drawer, rebuild_narrative)

func _update_fast_mode_btn_ui() -> void:
	ui["fast_mode_btn"].text = "⚡ Быстро" if api.fast_mode else "🧠 С мыслями"
	ui["fast_mode_btn"].modulate = Color("#fbbf24") if api.fast_mode else Color(1, 1, 1, 1)

func _on_fast_mode_toggled() -> void:
	api.fast_mode = !api.fast_mode
	_update_fast_mode_btn_ui()
	settings_drawer.save_settings()

func set_mode(mode: String) -> void:
	story.current_mode = mode
	layout.apply_mode_visibility(mode, is_generating, quest.is_game_active)
	update_smartbar_ui()
	rebuild_narrative()
	_trigger_auto_save()

func rebuild_narrative() -> void:
	NarrativeManager.render_log(ui["narrative_box"], story.get_active_log(), story.current_mode, layout.current_font_size)
	refresh_choices()

func refresh_choices() -> void:
	if choice_manager:
		choice_manager.refresh(is_generating)

func _on_meta_clicked(meta: Variant) -> void:
	var s = str(meta)
	if s.begins_with("toggle_think_"):
		var idx = int(s.substr(13))
		var log_arr = story.get_active_log()
		if idx >= 0 and idx < log_arr.size():
			log_arr[idx]["thinking_expanded"] = !log_arr[idx].get("thinking_expanded", false)
			rebuild_narrative()
			_trigger_auto_save()

func _on_copy_all_pressed() -> void:
	if sandbox_manager and sandbox_manager.is_active:
		sandbox_manager.copy_current_content()
		return
	DisplayServer.clipboard_set(ui["narrative_box"].get_parsed_text())
	show_toast("📋 Текст скопирован в буфер обмена!")

func show_toast(text: String) -> void:
	ui["live_status_label"].text = text
	ui["live_status_label"].modulate = Color("#38bdf8")
	await get_tree().create_timer(2.5).timeout
	if not is_generating and not is_bg_expanding and ui.has("live_status_label"):
		ui["live_status_label"].text = "🟢 Модель ожидает ваше действие"
		ui["live_status_label"].modulate = Color("#94a3b8")

func update_character_ui() -> void:
	var stats_text = ""
	for k in quest.stats:
		var icon = "❤️" if k == "HP" else "⏳"
		stats_text += "%s %s: %s   " % [icon, k, str(quest.stats[k])]
	ui["stats_label"].text = stats_text

	for child in ui["inventory_container"].get_children(): child.queue_free()
	for item in quest.inventory:
		var tag = Button.new()
		tag.text = item
		tag.disabled = true
		tag.add_theme_stylebox_override("disabled", GameStyle.create_inventory_tag_style())
		ui["inventory_container"].add_child(tag)

func set_ui_locked(locked: bool) -> void:
	is_generating = locked
	ui["input_text_edit"].editable = !locked
	ui["send_button"].disabled = locked
	ui["fast_mode_btn"].disabled = locked

	if not locked and not is_bg_expanding:
		ui["live_status_label"].text = "🟢 Модель ожидает ваше действие"
		ui["live_status_label"].modulate = Color("#94a3b8")
		ui["live_thinking_toggle_btn"].visible = false
		ui["live_thinking_box"].visible = false

	refresh_choices()

func _on_stream_status_changed(status_text: String, elapsed: float, tokens: int) -> void:
	ui["live_status_label"].text = "%s (⏱️ %.1fs | 🔢 %d tok)" % [status_text, elapsed, tokens]
	ui["live_status_label"].modulate = Color("#38bdf8")

func _on_token_received(delta: String) -> void:
	if story.current_mode == "chat":
		ui["narrative_box"].append_text(CommonStyle.format_bbcode(delta))

func _on_thinking_token_received(delta: String) -> void:
	ui["live_thinking_toggle_btn"].visible = true
	ui["live_thinking_box"].append_text(delta)