class_name SettingsDrawer
extends PanelContainer

signal settings_changed
signal clear_requested
signal models_loaded(count: int, err: String)
signal export_session_requested
signal import_session_requested

var api_address_input: LineEdit
var address_arrow_btn: Button
var address_dropdown: PanelContainer
var address_list_vbox: VBoxContainer

var api_token_input: LineEdit

var model_input: LineEdit
var model_arrow_btn: Button
var model_dropdown: PanelContainer
var model_list_vbox: VBoxContainer
var load_models_btn: Button

var current_anchor: Control = null
var toggle_button: Control = null

var is_open: bool = false
var address_presets: Array[String] = [
	"http://localhost:11434/v1",
	"https://openrouter.ai/api/v1",
	"https://api.deepseek.com/v1",
	"https://api.groq.com/openai/v1",
	"https://api.openai.com/v1",
	"https://api.f5ai.ru/v2",
	"https://api.anthropic.com",
	"https://generativelanguage.googleapis.com"
]
var address_history: Array = []
var available_models: Array = []
var model_history: Array = []
var address_to_last_model: Dictionary = {}

var api: ApiClient

const SETTINGS_FILE = "user://settings.json"

func _init() -> void:
	visible = false
	top_level = true
	z_index = 100

func setup(api_client: ApiClient) -> void:
	api = api_client
	load_settings()
	build_ui()

func build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var drawer_flow = HFlowContainer.new()
	drawer_flow.add_theme_constant_override("h_separation", 10)
	drawer_flow.add_theme_constant_override("v_separation", 10)

	var vp_w = 1200.0
	if is_inside_tree() and get_viewport():
		vp_w = get_viewport_rect().size.x
	var is_mobile = (vp_w < 950)

	var addr_wrap = HBoxContainer.new()
	addr_wrap.custom_minimum_size = Vector2(340 if not is_mobile else vp_w - 40, 46)
	addr_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	api_address_input = LineEdit.new()
	api_address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	api_address_input.placeholder_text = "API URL (Ollama, OpenRouter, DeepSeek...)"
	api_address_input.text = api.base_url
	api_address_input.focus_entered.connect(func(): _open_address_dropdown(""))
	api_address_input.focus_exited.connect(func(): _apply_custom_address(api_address_input.text))
	api_address_input.gui_input.connect(_on_address_input_gui_input)
	api_address_input.text_changed.connect(func(txt): _open_address_dropdown(txt))
	api_address_input.text_submitted.connect(_on_address_input_submitted)
	addr_wrap.add_child(api_address_input)

	address_arrow_btn = Button.new()
	address_arrow_btn.text = "▼"
	address_arrow_btn.custom_minimum_size = Vector2(40, 46)
	address_arrow_btn.pressed.connect(func():
		if address_dropdown.visible: address_dropdown.visible = false
		else: _open_address_dropdown("")
	)
	addr_wrap.add_child(address_arrow_btn)
	drawer_flow.add_child(addr_wrap)

	api_token_input = LineEdit.new()
	if is_mobile:
		api_token_input.custom_minimum_size = Vector2(vp_w - 40, 46)
	else:
		api_token_input.custom_minimum_size = Vector2(280, 46)
	api_token_input.placeholder_text = "API Key / Token (если требуется)"
	api_token_input.secret = true
	api_token_input.text = api.auth_token
	api_token_input.text_changed.connect(func(t): api.auth_token = t.strip_edges(); save_settings())
	drawer_flow.add_child(api_token_input)

	var model_wrap = HBoxContainer.new()
	model_wrap.custom_minimum_size = Vector2(240, 46)

	model_input = LineEdit.new()
	model_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_input.placeholder_text = "Модель..."
	model_input.text = api.model_name
	model_input.focus_entered.connect(func(): _open_model_dropdown(""))
	model_input.gui_input.connect(_on_model_input_gui_input)
	model_input.text_changed.connect(func(txt): _open_model_dropdown(txt))
	model_input.text_submitted.connect(_on_model_input_text_submitted)
	model_wrap.add_child(model_input)

	model_arrow_btn = Button.new()
	model_arrow_btn.text = "▼"
	model_arrow_btn.custom_minimum_size = Vector2(40, 46)
	model_arrow_btn.pressed.connect(func():
		if model_dropdown.visible: model_dropdown.visible = false
		else: _open_model_dropdown("")
	)
	model_wrap.add_child(model_arrow_btn)
	drawer_flow.add_child(model_wrap)

	load_models_btn = Button.new(); load_models_btn.text = "🔄 Обновить"
	load_models_btn.custom_minimum_size = Vector2(130, 46)
	load_models_btn.pressed.connect(_on_load_models_pressed)
	drawer_flow.add_child(load_models_btn)

	var export_btn = Button.new(); export_btn.text = "💾 Сохранить"
	export_btn.custom_minimum_size = Vector2(130, 46)
	export_btn.pressed.connect(func(): export_session_requested.emit())
	drawer_flow.add_child(export_btn)

	var import_btn = Button.new(); import_btn.text = "📂 Загрузить"
	import_btn.custom_minimum_size = Vector2(130, 46)
	import_btn.pressed.connect(func(): import_session_requested.emit())
	drawer_flow.add_child(import_btn)

	var clear_btn = Button.new(); clear_btn.text = "❌ Сбросить"; clear_btn.modulate = Color("#f87171")
	clear_btn.custom_minimum_size = Vector2(130, 46)
	clear_btn.pressed.connect(func(): clear_requested.emit())
	drawer_flow.add_child(clear_btn)

	add_child(drawer_flow)
	_build_dropdown_panels()

func _build_dropdown_panels() -> void:
	model_dropdown = _create_popup_panel()
	var m_scroll = ScrollContainer.new()
	m_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; m_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	CommonStyle.enable_touch_scroll(m_scroll)
	model_list_vbox = VBoxContainer.new(); model_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_list_vbox.add_theme_constant_override("separation", 4)
	m_scroll.add_child(model_list_vbox)
	model_dropdown.add_child(m_scroll)
	add_child(model_dropdown)

	address_dropdown = _create_popup_panel()
	var a_scroll = ScrollContainer.new()
	a_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; a_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	a_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	CommonStyle.enable_touch_scroll(a_scroll)
	address_list_vbox = VBoxContainer.new(); address_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_list_vbox.add_theme_constant_override("separation", 4)
	a_scroll.add_child(address_list_vbox)
	address_dropdown.add_child(a_scroll)
	add_child(address_dropdown)

func _create_popup_panel() -> PanelContainer:
	var p = PanelContainer.new()
	p.top_level = true; p.z_index = 120; p.visible = false
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#161d30"); sb.border_color = Color("#4facfe")
	sb.set_border_width_all(1); sb.set_corner_radius_all(6)
	sb.content_margin_left = 6; sb.content_margin_right = 6; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	return p

func _on_model_input_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_model_dropdown("")

func _open_model_dropdown(filter_text: String = "") -> void:
	if address_dropdown: address_dropdown.visible = false
	_populate_model_list(filter_text)
	_position_dropdown(model_input, model_dropdown, model_list_vbox, 320.0)
	model_dropdown.visible = true

func _populate_model_list(filter_text: String = "") -> void:
	for child in model_list_vbox.get_children(): child.queue_free()

	var q = filter_text.strip_edges().to_lower()
	var all_models = []
	
	for mh in model_history:
		if available_models.has(mh) and not all_models.has(mh): all_models.append(mh)
	
	for m in available_models:
		if not all_models.has(m): all_models.append(m)

	if all_models.size() == 0 and api.model_name != "": 
		all_models = [api.model_name]

	var matched: Array[String] = []
	for m in all_models:
		if q == "" or str(m).to_lower().contains(q):
			matched.append(str(m))

	if matched.size() == 0:
		var empty_lbl = Label.new(); empty_lbl.text = "Модели не найдены"; empty_lbl.modulate = Color("#94a3b8")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		model_list_vbox.add_child(empty_lbl)
	else:
		for m in matched:
			var btn = Button.new(); btn.text = m; btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 40)
			btn.mouse_filter = Control.MOUSE_FILTER_PASS
			if m == api.model_name: btn.modulate = Color("#38bdf8")
			btn.pressed.connect(func(): _select_model(m))
			model_list_vbox.add_child(btn)

func _select_model(m: String) -> void:
	api.model_name = m
	model_input.text = m
	model_dropdown.visible = false
	address_to_last_model[api.base_url] = m
	
	model_history.erase(m)
	model_history.insert(0, m)
	if model_history.size() > 15: model_history.pop_back()
	
	save_settings()
	settings_changed.emit()

func _on_model_input_text_submitted(new_text: String) -> void:
	var trimmed = new_text.strip_edges()
	if trimmed != "":
		_select_model(trimmed)

func _on_address_input_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_address_dropdown("")

func _open_address_dropdown(filter_text: String = "") -> void:
	if model_dropdown: model_dropdown.visible = false
	_populate_address_list(filter_text)
	_position_dropdown(api_address_input, address_dropdown, address_list_vbox, 520.0)
	address_dropdown.visible = true

func _populate_address_list(filter_text: String = "") -> void:
	for child in address_list_vbox.get_children(): child.queue_free()

	var all_opts = []
	for h in address_history: if not all_opts.has(h): all_opts.append(h)
	for p in address_presets: if not all_opts.has(p): all_opts.append(p)

	var q = filter_text.strip_edges().to_lower()
	var matched: Array[String] = []
	for addr in all_opts:
		if q == "" or addr.to_lower().contains(q): matched.append(addr)

	if matched.size() == 0:
		var empty_lbl = Label.new(); empty_lbl.text = "Адреса не найдены"; empty_lbl.modulate = Color("#94a3b8")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		address_list_vbox.add_child(empty_lbl)
	else:
		for addr in matched:
			var row = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var btn = Button.new(); btn.text = addr; btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 40)
			btn.mouse_filter = Control.MOUSE_FILTER_PASS
			if addr == api.base_url: btn.modulate = Color("#38bdf8")
			btn.pressed.connect(func(): _select_address_and_refresh(addr))
			row.add_child(btn)

			if address_history.has(addr):
				var del_btn = Button.new(); del_btn.text = "✕"; del_btn.modulate = Color("#f87171")
				del_btn.custom_minimum_size = Vector2(40, 40)
				del_btn.mouse_filter = Control.MOUSE_FILTER_PASS
				del_btn.pressed.connect(func(): _remove_address_from_history(addr))
				row.add_child(del_btn)

			address_list_vbox.add_child(row)

func _select_address_and_refresh(url: String) -> void:
	address_history.erase(url)
	address_history.insert(0, url)
	
	api_address_input.text = url
	api.base_url = url
	address_dropdown.visible = false

	if address_to_last_model.has(url):
		var prev_model = address_to_last_model[url]
		if prev_model != "":
			api.model_name = prev_model
			model_input.text = prev_model
			settings_changed.emit()

	save_settings()
	_on_load_models_pressed()

func _remove_address_from_history(addr: String) -> void:
	address_history.erase(addr)
	save_settings()
	_populate_address_list(api_address_input.text)

func _apply_custom_address(raw_url: String) -> void:
	var clean = raw_url.strip_edges()
	if clean == "": return
	api.base_url = clean
	
	address_history.erase(clean)
	address_history.insert(0, clean)
	if address_history.size() > 15: address_history.pop_back()
	
	save_settings()
	settings_changed.emit()

func _on_address_input_submitted(new_text: String) -> void:
	_apply_custom_address(new_text)
	address_dropdown.visible = false
	_on_load_models_pressed()

func _position_dropdown(anchor: Control, popup: Control, list_vbox: Control, min_w: float = 320.0) -> void:
	if not anchor or not is_instance_valid(anchor): return
	var rect = anchor.get_global_rect()
	var vp_w = get_viewport_rect().size.x if is_inside_tree() else 1200.0
	var w = clamp(max(rect.size.x + 40.0, min_w), 280.0, vp_w - 20.0)
	var count = list_vbox.get_child_count()
	var h = clamp(count * 42.0 + 16.0, 50.0, 270.0)
	popup.global_position = Vector2(clamp(rect.position.x, 10.0, vp_w - w - 10.0), rect.position.y + rect.size.y + 4)
	popup.size = Vector2(w, h)
	popup.custom_minimum_size = Vector2(w, h)

func toggle_below(panel_anchor: Control, btn: Control = null) -> void:
	if is_open:
		close()
	else:
		open_below(panel_anchor, btn)

func open_below(panel_anchor: Control, btn: Control = null) -> void:
	current_anchor = panel_anchor
	toggle_button = btn if btn != null else panel_anchor
	var rect = panel_anchor.get_global_rect()
	var vp_w = get_viewport_rect().size.x if is_inside_tree() else 1200.0
	global_position = Vector2(rect.position.x, rect.position.y + rect.size.y + 4)
	size = Vector2(min(rect.size.x, vp_w - 16), 0)
	visible = true
	is_open = true

func close() -> void:
	visible = false
	is_open = false
	current_anchor = null
	toggle_button = null
	if model_dropdown: model_dropdown.visible = false
	if address_dropdown: address_dropdown.visible = false

func _input(event: InputEvent) -> void:
	if not visible: return

	if (model_dropdown and model_dropdown.visible) or (address_dropdown and address_dropdown.visible):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			if model_dropdown: model_dropdown.visible = false
			if address_dropdown: address_dropdown.visible = false
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseButton and event.pressed:
			var m_pos = event.global_position
			if model_dropdown and model_dropdown.visible:
				if not model_dropdown.get_global_rect().has_point(m_pos) and not model_input.get_global_rect().has_point(m_pos) and not model_arrow_btn.get_global_rect().has_point(m_pos):
					model_dropdown.visible = false
			if address_dropdown and address_dropdown.visible:
				if not address_dropdown.get_global_rect().has_point(m_pos) and not api_address_input.get_global_rect().has_point(m_pos) and not address_arrow_btn.get_global_rect().has_point(m_pos):
					address_dropdown.visible = false

	if not is_open: return
	if event is InputEventMouseButton and event.pressed:
		var m_pos = event.global_position
		var in_drawer = get_global_rect().has_point(m_pos)
		var in_m_dd = model_dropdown and model_dropdown.visible and model_dropdown.get_global_rect().has_point(m_pos)
		var in_a_dd = address_dropdown and address_dropdown.visible and address_dropdown.get_global_rect().has_point(m_pos)
		var in_toggle = toggle_button and is_instance_valid(toggle_button) and toggle_button.get_global_rect().has_point(m_pos)

		if not in_drawer and not in_m_dd and not in_a_dd and not in_toggle:
			close()

func _on_load_models_pressed() -> void:
	load_models_btn.disabled = true; load_models_btn.text = "Загрузка..."
	api.provider = "auto"
	api.auth_type = "auto"
	if not address_history.has(api.base_url) and not address_presets.has(api.base_url):
		address_history.insert(0, api.base_url)
		if address_history.size() > 15: address_history.pop_back()

	var res = await api.fetch_models(get_tree())
	if res.has("models") and res["models"].size() > 0:
		available_models.clear()
		for m in res["models"]: available_models.append(str(m))

		var chosen_model = ""
		if available_models.has(api.model_name):
			chosen_model = api.model_name
		else:
			var last_for_addr = address_to_last_model.get(api.base_url, "")
			if last_for_addr != "" and available_models.has(last_for_addr):
				chosen_model = last_for_addr
			else:
				chosen_model = available_models[0]
				for mh in model_history:
					if available_models.has(mh):
						chosen_model = mh
						break

		api.model_name = chosen_model
		model_input.text = chosen_model
		address_to_last_model[api.base_url] = chosen_model

		load_models_btn.text = "Готово (%d)" % available_models.size()
		models_loaded.emit(available_models.size(), "")
	else:
		var err = res.get("error", "Неизвестная ошибка")
		load_models_btn.text = "Ошибка"
		models_loaded.emit(0, err)

	save_settings()
	settings_changed.emit()
	await get_tree().create_timer(1.8).timeout
	load_models_btn.disabled = false; load_models_btn.text = "🔄 Обновить"

func save_settings() -> void:
	var data = {
		"base_url": api.base_url,
		"provider": api.provider,
		"auth_type": api.auth_type,
		"auth_token": api.auth_token,
		"model_name": api.model_name,
		"history": address_history,
		"model_history": model_history,
		"fast_mode": api.fast_mode,
		"available_models": available_models,
		"address_to_last_model": address_to_last_model
	}
	var f = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data, "  "))

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE): return
	var f = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if not f: return
	var json = JSON.parse_string(f.get_as_text())
	if json is Dictionary:
		api.base_url = json.get("base_url", api.base_url)
		api.provider = json.get("provider", "auto")
		api.auth_type = json.get("auth_type", "auto")
		api.auth_token = json.get("auth_token", "")
		api.model_name = json.get("model_name", api.model_name)
		api.fast_mode = json.get("fast_mode", true)
		address_history = json.get("history", [])
		model_history = json.get("model_history", [])
		available_models = json.get("available_models", [])
		address_to_last_model = json.get("address_to_last_model", {})