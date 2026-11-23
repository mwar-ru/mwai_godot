class_name SandboxManager
extends Node

var parent_control: Control
var ui: Dictionary
var api: ApiClient

var is_active: bool = false
var is_generating_game: bool = false
var current_game_title: String = "Мини-игра"
var current_code: String = ""
var current_game_instance: Control = null

var conversation_history: Array = []
var auto_repair_attempts: int = 0
const MAX_AUTO_REPAIRS: int = 5

var sandbox_panel: PanelContainer
var title_label: Label
var game_mount: Control
var chat_text_box: RichTextLabel
var code_text_edit: TextEdit
var btn_tab_game: Button
var btn_tab_chat: Button
var btn_tab_code: Button
var btn_save: Button
var btn_copy: Button

signal sandbox_closed

func setup(p_parent: Control, p_ui: Dictionary, p_api: ApiClient) -> void:
    parent_control = p_parent
    ui = p_ui
    api = p_api
    _build_sandbox_ui()

func _build_sandbox_ui() -> void:
    sandbox_panel = PanelContainer.new()
    sandbox_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    sandbox_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sandbox_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sandbox_panel.visible = false

    var sb_style = StyleBoxFlat.new()
    sb_style.bg_color = Color("#0f1322")
    sb_style.border_color = Color("#38bdf8")
    sb_style.set_border_width_all(1)
    sb_style.set_corner_radius_all(8)
    sb_style.content_margin_left = 10
    sb_style.content_margin_right = 10
    sb_style.content_margin_top = 8
    sb_style.content_margin_bottom = 8
    sandbox_panel.add_theme_stylebox_override("panel", sb_style)

    var main_vbox = VBoxContainer.new()
    main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    main_vbox.add_theme_constant_override("separation", 8)
    sandbox_panel.add_child(main_vbox)

    var top_bar = HBoxContainer.new()
    top_bar.add_theme_constant_override("separation", 6)

    title_label = Label.new()
    title_label.text = "🎮 Песочница"
    title_label.modulate = Color("#38bdf8")
    title_label.add_theme_font_size_override("font_size", 16)
    top_bar.add_child(title_label)

    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_bar.add_child(spacer)

    btn_tab_game = Button.new()
    btn_tab_game.text = "🎮 Игра"
    btn_tab_game.custom_minimum_size = Vector2(75, 36)
    btn_tab_game.pressed.connect(func(): _switch_tab("game"))
    top_bar.add_child(btn_tab_game)

    btn_tab_chat = Button.new()
    btn_tab_chat.text = "💬 Чат"
    btn_tab_chat.custom_minimum_size = Vector2(75, 36)
    btn_tab_chat.pressed.connect(func(): _switch_tab("chat"))
    top_bar.add_child(btn_tab_chat)

    btn_tab_code = Button.new()
    btn_tab_code.text = "📜 Код"
    btn_tab_code.custom_minimum_size = Vector2(70, 36)
    btn_tab_code.pressed.connect(func(): _switch_tab("code"))
    top_bar.add_child(btn_tab_code)

    btn_copy = Button.new()
    btn_copy.text = "📋"
    btn_copy.tooltip_text = "Скопировать текущий код или чат"
    btn_copy.custom_minimum_size = Vector2(38, 36)
    btn_copy.pressed.connect(copy_current_content)
    top_bar.add_child(btn_copy)

    btn_save = Button.new()
    btn_save.text = "💾"
    btn_save.tooltip_text = "Сохранить мини-игру в файл"
    btn_save.custom_minimum_size = Vector2(38, 36)
    btn_save.pressed.connect(func(): export_sandbox_game())
    top_bar.add_child(btn_save)

    var btn_restart = Button.new()
    btn_restart.text = "🔄"
    btn_restart.tooltip_text = "Перезапустить игру"
    btn_restart.custom_minimum_size = Vector2(38, 36)
    btn_restart.pressed.connect(restart_current_game)
    top_bar.add_child(btn_restart)

    var btn_close = Button.new()
    btn_close.text = "❌"
    btn_close.tooltip_text = "Выйти из песочницы в меню квестов"
    btn_close.modulate = Color("#f87171")
    btn_close.custom_minimum_size = Vector2(38, 36)
    btn_close.pressed.connect(close_sandbox)
    top_bar.add_child(btn_close)

    main_vbox.add_child(top_bar)

    var content_area = Control.new()
    content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_vbox.add_child(content_area)

    game_mount = Control.new()
    game_mount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    game_mount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    game_mount.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_area.add_child(game_mount)

    chat_text_box = RichTextLabel.new()
    chat_text_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    chat_text_box.bbcode_enabled = true
    chat_text_box.scroll_following = true
    chat_text_box.selection_enabled = true
    chat_text_box.context_menu_enabled = true
    chat_text_box.visible = false
    content_area.add_child(chat_text_box)

    code_text_edit = TextEdit.new()
    code_text_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    code_text_edit.editable = false
    code_text_edit.selecting_enabled = true
    code_text_edit.context_menu_enabled = true
    code_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    code_text_edit.visible = false
    content_area.add_child(code_text_edit)

    if ui.has("narrative_container"):
        ui["narrative_container"].add_child(sandbox_panel)
    else:
        parent_control.add_child(sandbox_panel)

func _switch_tab(tab: String) -> void:
    game_mount.visible = (tab == "game")
    chat_text_box.visible = (tab == "chat")
    code_text_edit.visible = (tab == "code")
    btn_tab_game.modulate = Color("#38bdf8") if tab == "game" else Color.WHITE
    btn_tab_chat.modulate = Color("#38bdf8") if tab == "chat" else Color.WHITE
    btn_tab_code.modulate = Color("#38bdf8") if tab == "code" else Color.WHITE

func copy_current_content() -> void:
    if code_text_edit.visible and current_code != "":
        DisplayServer.clipboard_set(current_code)
        if parent_control.has_method("show_toast"):
            parent_control.call("show_toast", "📋 Код скопирован в буфер!")
    elif chat_text_box.visible:
        DisplayServer.clipboard_set(chat_text_box.get_parsed_text())
        if parent_control.has_method("show_toast"):
            parent_control.call("show_toast", "📋 Чат скопирован в буфер!")
    else:
        if current_code != "":
            DisplayServer.clipboard_set(current_code)
            if parent_control.has_method("show_toast"):
                parent_control.call("show_toast", "📋 Код игры скопирован в буфер!")

func start_new_game(user_prompt: String) -> void:
    is_active = true
    is_generating_game = true
    auto_repair_attempts = 0
    current_game_title = user_prompt
    title_label.text = "🎮 " + user_prompt

    if ui.has("welcome_scroll"): ui["welcome_scroll"].visible = false
    if ui.has("welcome_panel"): ui["welcome_panel"].visible = false
    if ui.has("narrative_box"): ui["narrative_box"].visible = false
    if ui.has("choices_container"): ui["choices_container"].visible = false
    sandbox_panel.visible = true
    _switch_tab("chat")

    chat_text_box.clear()
    chat_text_box.append_text("[color=#38bdf8][b]Вы:[/b] %s[/color]\n\n" % user_prompt)
    chat_text_box.append_text("[color=#94a3b8]⏳ ИИ проектирует игру и пишет чистый код на GDScript...[/color]\n\n")

    var system_prompt = "Ты — элитный разработчик игр на Godot 4 (GDScript).\n"
    system_prompt += "Твоя задача — написать полностью рабочий код мини-игры или виджета по запросу пользователя.\n\n"
    system_prompt += "СТРОЖАЙШИЕ ПРАВИЛА GDScript:\n"
    system_prompt += "1. Первая строка: extends Control\n"
    system_prompt += "2. Инициализируй массивы через []: var arr: Array = []. НЕ ИСПОЛЬЗУЙ Array.new()!\n"
    system_prompt += "3. Не используй ':=' для неявного вывода типов. Пиши обычный '=': var x = 1, var p = PanelContainer.new().\n"
    system_prompt += "4. В GDSCRIPT НЕТ ТЕРНАРНОГО ОПЕРАТОРА (cond ? a : b)! Символ '?' СТРОГО ЗАПРЕЩЁН! Пиши ТОЛЬКО: a if cond else b.\n"
    system_prompt += "5. Кнопка — это Button! У PanelContainer НЕТ сигнала pressed! Для кликабельных клеток используй Button.new().\n"
    system_prompt += "6. Запрещены $NodeName и get_node(). Создавай узлы через Node.new() и add_child().\n"
    system_prompt += "7. Запрещены вложенные типы Array[Array[int]]. Пиши: var win: Array = [...]\n"
    system_prompt += "8. Клавиши: KEY_R, KEY_ESCAPE, а не Key.R.\n\n"
    system_prompt += "ЭТАЛОННЫЙ ПРИМЕР СЕТКИ КНОПОК:\n"
    system_prompt += "```gdscript\n"
    system_prompt += "extends Control\n\n"
    system_prompt += "var grid: GridContainer\n"
    system_prompt += "var status_lbl: Label\n\n"
    system_prompt += "func _ready() -> void:\n"
    system_prompt += "  set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n"
    system_prompt += "  var vbox = VBoxContainer.new()\n"
    system_prompt += "  vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n"
    system_prompt += "  vbox.alignment = BoxContainer.ALIGNMENT_CENTER\n"
    system_prompt += "  add_child(vbox)\n\n"
    system_prompt += "  status_lbl = Label.new()\n"
    system_prompt += "  status_lbl.text = 'Крестики-нолики'\n"
    system_prompt += "  vbox.add_child(status_lbl)\n\n"
    system_prompt += "  var center = CenterContainer.new()\n"
    system_prompt += "  vbox.add_child(center)\n\n"
    system_prompt += "  grid = GridContainer.new()\n"
    system_prompt += "  grid.columns = 3\n"
    system_prompt += "  center.add_child(grid)\n\n"
    system_prompt += "  for i in range(9):\n"
    system_prompt += "      var btn = Button.new()\n"
    system_prompt += "      btn.custom_minimum_size = Vector2(85, 85)\n"
    system_prompt += "      btn.pressed.connect(_on_btn.bind(i))\n"
    system_prompt += "      grid.add_child(btn)\n\n"
    system_prompt += "func _on_btn(idx: int) -> void:\n"
    system_prompt += "  pass\n"
    system_prompt += "```\n\n"
    system_prompt += "Выведи полный код игры внутри блока ```gdscript ... ``` без посторонних рассуждений."

    conversation_history = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "Создай игру: " + user_prompt}
    ]

    api.send_chat(conversation_history, get_tree(), true)

func edit_game(edit_prompt: String) -> void:
    is_generating_game = true
    auto_repair_attempts = 0
    chat_text_box.append_text("[color=#38bdf8][b]Правка:[/b] %s[/color]\n\n" % edit_prompt)
    chat_text_box.append_text("[color=#94a3b8]⏳ Применение изменений к коду игры...[/color]\n\n")

    var user_msg = "Внеси правки в текущую игру: \"" + edit_prompt + "\"\n\n"
    user_msg += "Текущий код игры:\n```gdscript\n" + current_code + "\n```\n\n"
    user_msg += "Выдай ПОЛНЫЙ обновлённый код игры в блоке ```gdscript ... ``` с соблюдением правил Godot 4 (Button для кликабельных клеток, без Array.new, без $Node, без '?' тернарного оператора)."

    conversation_history.append({"role": "user", "content": user_msg})
    api.send_chat(conversation_history, get_tree(), true)

func _trigger_auto_repair(error_reason: String) -> void:
    if auto_repair_attempts >= MAX_AUTO_REPAIRS:
        chat_text_box.append_text("[color=#f87171]❌ Не удалось автоматически исправить код после 5 попыток. Ошибка: %s[/color]\n\n" % error_reason)
        _switch_tab("chat")
        return

    auto_repair_attempts += 1
    is_generating_game = true
    parent_control.call("set_ui_locked", true)
    ui["live_status_label"].text = "🛠️ ИИ исправляет ошибку в коде (попытка %d из %d)..." % [auto_repair_attempts, MAX_AUTO_REPAIRS]
    chat_text_box.append_text("[color=#fbbf24]⚠️ Ошибка в коде (попытка %d): %s. Запущен авто-ремонт...[/color]\n\n" % [auto_repair_attempts, error_reason])

    var repair_msg = "Твой код вызвал ошибку в Godot 4:\n"
    repair_msg += "ОШИБКА: " + error_reason + "\n\n"
    repair_msg += "ОБЯЗАТЕЛЬНЫЕ ПРАВИЛА:\n"
    repair_msg += "1. Используй Button.new() для клеток, НЕ используй PanelContainer (у него нет pressed)!\n"
    repair_msg += "2. Инициализируй массивы через []: var a = [], НЕ используй Array.new()!\n"
    repair_msg += "3. Не используй ':='. Пиши обычный '=': var x = 0.\n"
    repair_msg += "4. Удали '?' тернарные операторы! Пиши 'b if a else c' или обычный if/else.\n"
    repair_msg += "5. НЕ используй Array[Array[int]]. Пиши var win: Array = [...].\n"
    repair_msg += "6. Не используй $NodeName или get_node().\n\n"
    repair_msg += "Выдай ПОЛНЫЙ исправленный код в блоке ```gdscript ... ```."

    conversation_history.append({"role": "user", "content": repair_msg})
    api.send_chat(conversation_history, get_tree(), true)

func on_stream_completed(narrative: String, _thinking: String, stats: Dictionary) -> void:
    is_generating_game = false
    conversation_history.append({"role": "assistant", "content": narrative})

    # Текст ответа модели
    chat_text_box.append_text("[color=#cbd5e1]%s[/color]\n\n" % narrative)

    # Метаданные (модель, время, токены), как в основном чате
    var used_model = api.model_name
    var content_time = stats.get("content_time", 0.0)
    var content_tokens = stats.get("content_tokens", 0)
    var meta_line = "🤖 %s | ⏱️ %.1fs | 🔢 %d tok" % [used_model, content_time, content_tokens]
    chat_text_box.append_text("[color=#64748b][font_size=13]%s[/font_size][/color]\n\n" % meta_line)

    var extracted = _extract_gdscript(narrative)
    if extracted != "":
        current_code = extracted
        code_text_edit.text = current_code
        _compile_and_run(current_code)
    else:
        chat_text_box.append_text("[color=#f87171]❌ В ответе не найден блок кода GDScript.[/color]\n\n")
        _trigger_auto_repair("В твоём ответе отсутствует блок кода ```gdscript ... ```. Сгенерируй код игры.")

func on_stream_error(msg: String) -> void:
    is_generating_game = false
    chat_text_box.append_text("[color=#f87171]❌ Ошибка API: %s[/color]\n\n" % msg)
    _switch_tab("chat")

func _extract_gdscript(text: String) -> String:
    var re = RegEx.create_from_string("(?s)```(?:gdscript|godot|gd)?\\s*\\n(extends\\s+Control.*?)\\n```")
    var m = re.search(text)
    if m:
        return m.get_string(1).strip_edges()

    var start = text.find("extends Control")
    if start != -1:
        var end = text.find("```", start)
        if end != -1:
            return text.substr(start, end - start).strip_edges()
        return text.substr(start).strip_edges()
    return ""

# Автоматическая очистка и исправление типичных галлюцинаций ИИ перед компиляцией
func _sanitize_code(code: String) -> String:
    var clean = code

    # 1. Заменяем Array.new() и Dictionary.new() на встроенные литералы
    clean = clean.replace("Array.new()", "[]")
    clean = clean.replace("Dictionary.new()", "{}")

    # 2. Заменяем строгий вывод типа := на обычный = (устраняет ошибку Cannot infer type from Variant)
    clean = RegEx.create_from_string("(?<!:):=([^=])").sub(clean, "= $1", true)

    # 3. АВТО-КОНВЕРТЕР ТЕРНАРНОГО ОПЕРАТОРА: var x = cond ? a : b  ->  var x = a if cond else b
    var re_ternary = RegEx.create_from_string("(?m)^([ \\t]*(?:var\\s+\\w+(?:\\s*:\\s*\\w+)?\\s*=|return|[\\w\\[\\]\\.]+\\s*=)\\s*)([^?\\r\\n]+?)\\s*\\?\\s*([^:\\r\\n]+?)\\s*:\\s*([^;\\r\\n]+)$")
    clean = re_ternary.sub(clean, "$1$3 if $2 else $4", true)

    # 4. Заменяем запрещённые вложенные типы Array[Array[...]] на безопасный Array
    var re_nested_array = RegEx.create_from_string("Array\\[\\s*Array\\[[^\\]]*\\]\\s*\\]")
    clean = re_nested_array.sub(clean, "Array", true)

    # 5. Удаляем строки со слэшами в начале (например /board.set_...)
    var re_slash_lines = RegEx.create_from_string("(?m)^[ \\t]*/+.*$\\r?\\n?")
    clean = re_slash_lines.sub(clean, "", true)

    # 6. Удаляем вызовы несуществующих свойств GridContainer
    var re_fake_grid = RegEx.create_from_string("(?m)^[ \\t]*\\w+\\.(?:set_rows|set_row_gap|set_column_gap|cell_size|cell_size_min_size|set_anchor_\\w+)\\s*[:=(].*$\\r?\\n?")
    clean = re_fake_grid.sub(clean, "", true)

    # 7. Исправляем несуществующую функцию cast(Node, val) на чистый val
    var re_fake_cast = RegEx.create_from_string("cast\\s*\\([^,]+,\\s*([^\\)]+)\\)")
    clean = re_fake_cast.sub(clean, "$1", true)

    # 8. Заменяем несуществующий get_child_at на get_child
    clean = clean.replace(".get_child_at(", ".get_child(")

    # 9. Заменяем ошибочный Key.R на KEY_R
    var re_key = RegEx.create_from_string("\\bKey\\.([A-Z0-9_]+)\\b")
    clean = re_key.sub(clean, "KEY_$1", true)

    # 10. Снимаем опасный каст массивов: as Array[Button] -> ничего
    var re_arr_cast = RegEx.create_from_string("as\\s+Array\\[\\w+\\]")
    clean = re_arr_cast.sub(clean, "", true)

    # 11. Исправляем add_theme_constant_override с числом в кавычках ("10" -> 10)
    var re_theme_int = RegEx.create_from_string('add_theme_constant_override\\s*\\(\\s*("[^"]+")\\s*,\\s*"(\\d+)"\\s*\\)')
    clean = re_theme_int.sub(clean, "add_theme_constant_override($1, $2)", true)

    # 12. Удаляем выдуманные константы Control.OFFSET_*
    var re_offset = RegEx.create_from_string('\\bControl\\.OFFSET_\\w+\\b')
    clean = re_offset.sub(clean, "0", true)

    return clean

func _compile_and_run(code: String) -> void:
    if is_instance_valid(current_game_instance):
        current_game_instance.queue_free()
        current_game_instance = null

    var sanitized = _sanitize_code(code)

    var script = GDScript.new()
    script.source_code = sanitized
    var err = script.reload()

    if err != OK:
        var specific_err = "Код не скомпилировался движком Godot 4 (ошибка reload() = %d)." % err
        if "?" in sanitized:
            specific_err = "В коде найден символ '?' (тернарный оператор). В GDScript знака '?' нет! Используй: a if cond else b."
        elif "Array.new" in sanitized:
            specific_err = "Array.new() запрещён. Инициализируй через []: var a = []."
        elif "PanelContainer" in sanitized and ".pressed" in sanitized:
            specific_err = "У PanelContainer нет сигнала pressed! Для клеток используй Button.new()."
        _trigger_auto_repair(specific_err)
        return

    var instance = script.new()
    if not (instance is Control):
        _trigger_auto_repair("Скрипт обязан расширять Control (extends Control) в первой строке.")
        return

    current_game_instance = instance
    current_game_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    current_game_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    current_game_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL

    game_mount.add_child(current_game_instance)
    _switch_tab("game")
    auto_repair_attempts = 0
    chat_text_box.append_text("[color=#2ecc71]✅ Игра успешно скомпилирована и запущена![/color]\n\n")

func restart_current_game() -> void:
    if current_code != "":
        _compile_and_run(current_code)

func close_sandbox() -> void:
    if is_instance_valid(current_game_instance):
        current_game_instance.queue_free()
        current_game_instance = null

    is_active = false
    is_generating_game = false
    current_code = ""
    conversation_history.clear()
    sandbox_panel.visible = false

    if ui.has("welcome_scroll"): ui["welcome_scroll"].visible = true
    if ui.has("welcome_panel"): ui["welcome_panel"].visible = true
    sandbox_closed.emit()

func export_sandbox_game() -> String:
    if current_code == "":
        return ""

    var downloads_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
    var base_folder = downloads_dir + "/mwai_playground/saved_games"
    DirAccess.make_dir_recursive_absolute(base_folder)

    var safe_title = current_game_title.to_lower()
    var re = RegEx.create_from_string("[^a-zA-Z0-9_]")
    safe_title = re.sub(safe_title, "_", true).strip_edges()
    if safe_title.length() > 30:
        safe_title = safe_title.substr(0, 30)

    var file_name = "game_" + safe_title + "_" + str(int(Time.get_unix_time_from_system())) + ".json"
    var full_path = base_folder + "/" + file_name

    var data = {
        "type": "sandbox_game",
        "version": 1,
        "title": current_game_title,
        "saved_at": Time.get_datetime_string_from_system(),
        "sandbox_code": current_code,
        "conversation_history": conversation_history
    }

    var f = FileAccess.open(full_path, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data, "  "))
        chat_text_box.append_text("[color=#2ecc71]💾 Игра успешно сохранена в файл:\n%s[/color]\n\n" % full_path)
        if parent_control.has_method("show_toast"):
            parent_control.call("show_toast", "💾 Игра сохранена в Downloads!")
        return full_path
    return ""

func load_game_from_data(data: Dictionary) -> bool:
    var code = data.get("sandbox_code", "")
    if code == "":
        return false

    is_active = true
    is_generating_game = false
    current_game_title = data.get("title", "Загруженная игра")
    title_label.text = "🎮 " + current_game_title
    current_code = code
    code_text_edit.text = code
    conversation_history = data.get("conversation_history", []).duplicate(true)

    if ui.has("welcome_scroll"): ui["welcome_scroll"].visible = false
    if ui.has("welcome_panel"): ui["welcome_panel"].visible = false
    if ui.has("narrative_box"): ui["narrative_box"].visible = false
    if ui.has("choices_container"): ui["choices_container"].visible = false
    sandbox_panel.visible = true

    chat_text_box.clear()
    chat_text_box.append_text("[color=#38bdf8]📂 Загружена игра: [b]%s[/b][/color]\n\n" % current_game_title)

    _compile_and_run(current_code)
    return true