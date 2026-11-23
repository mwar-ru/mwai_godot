class_name LayoutController
extends RefCounted

var host: Control
var ui: Dictionary = {}
var is_mobile_view: bool = false
var current_font_size: int = 15

# Минимальная высота блока карты и статуса при сужении окна
const MIN_TOP_BLOCK_HEIGHT: float = 220.0

# Кэш состояний для оптимизации ресайза
var _last_is_mobile_view: Variant = null
var _last_font_size: int = -1
var _last_btn_h: float = -1.0

func _init(p_host: Control, p_ui: Dictionary) -> void:
	host = p_host
	ui = p_ui

func update_layout(current_mode: String, quest_active: bool, is_generating: bool, quest, settings_drawer, on_rebuild_narrative: Callable) -> void:
	if not ui.has("narrative_box") or not ui.has("map_panel"): return
	var win = host.get_window()
	var win_size = win.size

	# Вертикальная ориентация определяется по физическому соотношению сторон окна
	is_mobile_view = (win_size.x < win_size.y or win_size.x < 750)

	# 1. МАСШТАБИРОВАНИЕ ДВИЖКА
	if is_mobile_view != _last_is_mobile_view:
		_last_is_mobile_view = is_mobile_view
		if is_mobile_view:
			# Масштабирование привязано к высоте, ширина не уменьшает размер элементов
			win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
			win.content_scale_size = Vector2i(0, 800)
		else:
			win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
			win.content_scale_size = Vector2i(1200, 800)

		# Переподключение панелей только при смене ориентации
		if ui["map_panel"].get_parent(): ui["map_panel"].get_parent().remove_child(ui["map_panel"])
		if ui["char_panel"].get_parent(): ui["char_panel"].get_parent().remove_child(ui["char_panel"])
		if is_mobile_view:
			ui["mobile_top_row"].add_child(ui["map_panel"])
			ui["mobile_top_row"].add_child(ui["char_panel"])
		else:
			ui["desktop_right_vbox"].add_child(ui["map_panel"])
			ui["desktop_right_vbox"].add_child(ui["char_panel"])

	var vp = host.get_viewport_rect().size

	# 2. РАЗМЕР ШРИФТА: для вертикальной верстки увеличен до 18px (для десктопа 15px)
	current_font_size = 23 if is_mobile_view else 15
	var font_changed = (current_font_size != _last_font_size)
	if font_changed:
		_last_font_size = current_font_size
		host.theme.set_font_size("font_size", "Button", current_font_size)
		host.theme.set_font_size("font_size", "Label", current_font_size)
		host.theme.set_font_size("font_size", "LineEdit", current_font_size)
		host.theme.set_font_size("font_size", "TextEdit", current_font_size)
		host.theme.set_font_size("font_size", "OptionButton", current_font_size)

		ui["narrative_box"].add_theme_font_size_override("normal_font_size", current_font_size)
		ui["narrative_box"].add_theme_font_size_override("bold_font_size", current_font_size)
		ui["narrative_box"].add_theme_font_size_override("italics_font_size", current_font_size)
		ui["narrative_box"].add_theme_font_size_override("bold_italics_font_size", current_font_size)
		ui["narrative_box"].add_theme_font_size_override("mono_font_size", current_font_size)

		on_rebuild_narrative.call()

	# 3. ВЫСОТА ЭЛЕМЕНТОВ (для вертикальной верстки кнопки крупнее: 48–56px)
	var base_btn_h = 48.0 if is_mobile_view else 38.0
	if abs(base_btn_h - _last_btn_h) > 0.5:
		_last_btn_h = base_btn_h
		ui["smart_bar_button"].custom_minimum_size.y = base_btn_h + 6.0
		ui["mode_chat_btn"].custom_minimum_size.y = base_btn_h
		ui["mode_game_btn"].custom_minimum_size.y = base_btn_h
		ui["start_gen_btn"].custom_minimum_size.y = base_btn_h + 4.0
		ui["load_file_btn"].custom_minimum_size.y = base_btn_h + 4.0
		ui["input_text_edit"].custom_minimum_size.y = base_btn_h + 8.0
		ui["fast_mode_btn"].custom_minimum_size.y = base_btn_h + 8.0
		ui["send_button"].custom_minimum_size.y = base_btn_h + 8.0
		ui["send_button"].custom_minimum_size.x = base_btn_h + 8.0

	# Адаптация ширин кнопок
	if is_mobile_view:
		ui["mode_chat_btn"].custom_minimum_size.x = 85.0
		ui["mode_game_btn"].custom_minimum_size.x = 85.0
		ui["smart_bar_button"].custom_minimum_size.x = 100.0
		# 135px дает достаточный запас под увеличенный 18px шрифт для "🧠 С мыслями"
		if ui.has("fast_mode_btn"): ui["fast_mode_btn"].custom_minimum_size.x = 135.0
	else:
		ui["mode_chat_btn"].custom_minimum_size.x = 110.0
		ui["mode_game_btn"].custom_minimum_size.x = 110.0
		ui["smart_bar_button"].custom_minimum_size.x = 180.0
		if ui.has("fast_mode_btn"): ui["fast_mode_btn"].custom_minimum_size.x = 140.0

	if settings_drawer and settings_drawer.is_open and font_changed:
		settings_drawer.build_ui()

	# 4. ПОЗИЦИОНИРОВАНИЕ
	var is_game = (current_mode == "game")
	if is_mobile_view:
		ui["desktop_right_vbox"].visible = false
		ui["mobile_top_row"].visible = is_game

		var margin_w = 16.0
		var sep_w = 8.0
		# Ширина делится ровно 50/50
		var half_w = int(max(80.0, (vp.x - margin_w - sep_w) * 0.5))

		# Высота блока не уменьшается ниже 220px, но ширина продолжает сужаться 50/50
		var top_h = max(MIN_TOP_BLOCK_HEIGHT, float(half_w))

		ui["mobile_top_row"].custom_minimum_size = Vector2(0, top_h)

		ui["map_panel"].custom_minimum_size = Vector2(half_w, top_h)
		ui["map_panel"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui["map_panel"].size_flags_vertical = Control.SIZE_EXPAND_FILL

		ui["char_panel"].custom_minimum_size = Vector2(half_w, top_h)
		ui["char_panel"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui["char_panel"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		var right_w = int(clamp(vp.x * 0.28, 300.0, 400.0))
		var map_h = int(clamp(vp.y * 0.35, 200.0, 280.0))
		ui["mobile_top_row"].visible = false
		ui["desktop_right_vbox"].visible = is_game
		ui["desktop_right_vbox"].custom_minimum_size = Vector2(right_w, 0)
		ui["map_panel"].custom_minimum_size = Vector2(right_w, map_h)
		ui["char_panel"].custom_minimum_size = Vector2(0, 0)
		ui["char_panel"].size_flags_vertical = Control.SIZE_EXPAND_FILL
		ui["desktop_split"].split_offset = int(vp.x - right_w - 40)

	update_setting_input_height()
	ui["map_view"].queue_redraw()

func update_setting_input_height() -> void:
	if not ui.has("welcome_scroll") or not ui.has("setting_text_edit") or not ui.has("welcome_panel"):
		return
	var scroll: ScrollContainer = ui["welcome_scroll"]
	var panel: VBoxContainer = ui["welcome_panel"]
	var edit: TextEdit = ui["setting_text_edit"]

	var avail = scroll.size.y
	if avail < 80.0:
		return

	var min_edit_h = 80.0 if not is_mobile_view else 95.0
	var separation = panel.get_theme_constant("separation")
	var other_h: float = 0.0
	var visible_count = 0

	for child in panel.get_children():
		if child == edit or not (child is Control):
			continue
		var ctrl: Control = child
		if ctrl.visible:
			other_h += ctrl.get_combined_minimum_size().y
			visible_count += 1

	other_h += separation * visible_count

	var target_h = max(min_edit_h, avail - other_h - 16.0)
	if abs(edit.custom_minimum_size.y - target_h) > 1.0:
		edit.custom_minimum_size.y = target_h

func apply_mode_visibility(mode: String, is_generating: bool, quest_active: bool) -> void:
	var is_game = (mode == "game")
	ui["mode_chat_btn"].modulate = Color("#38bdf8") if mode == "chat" else Color(1, 1, 1, 0.6)
	ui["mode_game_btn"].modulate = Color("#38bdf8") if mode == "game" else Color(1, 1, 1, 0.6)

	var show_welcome = (is_game and not quest_active and not is_generating)
	if ui.has("welcome_scroll"): ui["welcome_scroll"].visible = show_welcome
	if ui.has("welcome_panel"): ui["welcome_panel"].visible = show_welcome
	if ui.has("narrative_box"): ui["narrative_box"].visible = not show_welcome
	if ui.has("choices_container"): ui["choices_container"].visible = (is_game and quest_active and not is_generating)

	if is_mobile_view:
		ui["mobile_top_row"].visible = is_game
		ui["desktop_right_vbox"].visible = false
	else:
		ui["mobile_top_row"].visible = false
		ui["desktop_right_vbox"].visible = is_game

	ui["input_text_edit"].placeholder_text = "Ваше действие в квесте... (Enter — отправить)" if is_game else "Введите сообщение ассистенту... (Enter — отправить)"

	if show_welcome:
		update_setting_input_height()