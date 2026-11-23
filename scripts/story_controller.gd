class_name StoryController
extends RefCounted

var quest: QuestEngine
var api: ApiClient

var game_story_log: Array = []
var chat_story_log: Array = []
var chat_queue: Array = []
var dynamic_game_choices: Array = []

var game_tokens: int = 0
var chat_tokens: int = 0
var game_context_tokens: int = 0
var chat_context_tokens: int = 0

var current_mode: String = "game"
var pending_user_action: String = ""
var active_generation_model: String = ""
var is_expanding_world: bool = false

signal ui_update_requested
signal story_entry_added
signal choices_changed
signal bg_expansion_state_changed(is_running: bool, status_msg: String, tokens: int, elapsed: float)

func _init(p_quest: QuestEngine, p_api: ApiClient) -> void:
	quest = p_quest
	api = p_api
	chat_story_log.append({
		"action": "", "narrative": "Чат готов к работе. Выберите модель в статус-баре наверху.",
		"thinking": "", "stats": {}, "meta": "", "model": api.model_name, "address": api.base_url, "thinking_expanded": false
	})

func get_active_log() -> Array:
	return game_story_log if current_mode == "game" else chat_story_log

func add_story_entry(action_text: String, narrative_text: String, thinking_text: String = "", stats_data: Dictionary = {}, meta_str: String = "", model_label: String = "", addr_label: String = "") -> void:
	var chosen_m = model_label if model_label != "" else api.model_name
	var chosen_a = addr_label if addr_label != "" else api.base_url
	get_active_log().append({
		"action": action_text, "narrative": narrative_text, "thinking": thinking_text,
		"stats": stats_data, "meta": meta_str, "model": chosen_m, "address": chosen_a, "thinking_expanded": false
	})
	story_entry_added.emit()

func clear_current_log() -> void:
	if current_mode == "game":
		game_story_log.clear()
		game_tokens = 0
		game_context_tokens = 0
		quest.is_game_active = false
	else:
		chat_story_log.clear()
		chat_tokens = 0
		chat_context_tokens = 0
		chat_queue.clear()
		chat_story_log.append({
			"action": "", "narrative": "Диалог очищен.",
			"thinking": "", "stats": {}, "meta": "", "model": api.model_name, "address": api.base_url, "thinking_expanded": false
		})
	ui_update_requested.emit()

func check_and_trigger_world_expansion(tree: SceneTree) -> void:
	if is_expanding_world or not quest.should_expand_world():
		return
	is_expanding_world = true
	bg_expansion_state_changed.emit(true, "⚙️ Архитектор: Проектирование Акта %d..." % (quest.current_act + 1), 0, 0.0)

	quest.expand_act_in_background(
		api, tree,
		func(elapsed, tok):
			bg_expansion_state_changed.emit(true, "⚙️ Архитектор: Акт %d (⏱️ %.1fs | 🔢 %d tok)" % [quest.current_act, elapsed, tok], tok, elapsed),
		func(success, tok):
			is_expanding_world = false
			bg_expansion_state_changed.emit(false, "", 0, 0.0)
			if success:
				game_tokens += tok
				dynamic_game_choices = quest.generate_location_choices()
				choices_changed.emit()
				ui_update_requested.emit()
	)

func start_campaign_generation(setting_text: String, tree: SceneTree) -> void:
	game_story_log.clear()
	active_generation_model = api.model_name
	quest.campaign_stage = "intro"
	quest.current_chapter = 1
	quest.parse_scenario_params_from_text(setting_text)

	var p = quest.scenario_params
	var param_instructions = """
ПАРАМЕТРЫ СЦЕНАРИЯ (УСТАНОВЛЕНЫ ИГРОКОМ):
- Сложность: %s
- Запланировано актов: %s
- Локаций в этой зоне: %s
- Вариантов выбора на сцену: %s
- Количество концовок: %s
- Пермасмерть (высокий риск гибели): %s
- Глубина головоломок: %s
Строго соблюдай эти параметры при проектировании!""" % [
		p.get("difficulty", "hard"),
		p.get("acts", 3),
		p.get("locations_count", 5),
		p.get("choices_per_scene", 3),
		p.get("endings_count", 3),
		p.get("permadeath", true),
		p.get("puzzle_depth", "high")
	]

	var architect_prompt = """Ты — ведущий нарративный дизайнер и автор ролевых квестов высочайшего уровня ('Disco Elysium', 'Fallout 2', 'Космические рейнджеры').
Твоя задача — написать пролог и спроектировать Первую часть (Акт 1: Завязка) для глубокого текстового RPG-приключения.

СЕТТИНГ И ПАРАМЕТРЫ:
""" + setting_text + "\n" + param_instructions + """

ПРИНЦИПЫ КАЧЕСТВЕННОЙ ПРОЗЫ (КРИТИЧЕСКИ ВАЖНО):
1. Язык: пиши строго на языке сеттинга (если сеттинг на русском — безупречный выразительный русский язык).
2. Запрещены пустые клише («воздух можно резать ножом», «тишина звенела», «вы чувствуете страх»). Пиши через действия и фактуру: как скрипит ржавчина, как пахнет машинное масло, какие имена выцарапаны на стенах, о чём переговариваются патрульные.
3. Пролог ("narration"): ровно 3 атмосферных абзаца, погружающих игрока в безвыходное начальное положение и задающих главную глобальную цель побега/выживания.
4. Карта ("world_graph"): сгенерируй 4-5 логично соединённых локаций с развилками (не прямая кишка!).
5. В каждой локации: подробное описание "desc" (2 абзаца) и минимум 1 интересное действие с осязаемым последствием ("narration" на 2 абзаца).
6. Разметка сущностей: используй [предмет: Отмычка], [локация: Карцер], [персонаж: Надзиратель], [важно: Шифр]. В полях "inventory_add" пиши ЧИСТЫЕ имена без скобок и тегов!

ОТВЕТ СТРОГО В PURE JSON:
{
  "title": "Название кампании",
  "start_location": "Стартовая Зона",
  "narration": "Художественный пролог в 3 абзаца...",
  "initial_inventory": ["Предмет 1"],
  "initial_stats": {"HP": 100, "Дни": 80},
  "choices": [
    {
      "text": "Осмотреть тайник под нарами",
      "preview": "Проверить тайник",
      "narration": "Подробное литературное следствие выбора в 2 абзаца...",
      "inventory_add": ["Полезная вещь"]
    }
  ],
  "world_graph": {
    "Стартовая Зона": {
      "desc": "Атмосферное описание зоны в 2 абзаца...",
      "connections": ["Зона 2", "Зона 3"],
      "scripted_actions": []
    },
    "Зона 2": {
      "desc": "Описание Зоны 2 в 2 абзаца...",
      "connections": ["Стартовая Зона"],
      "scripted_actions": []
    },
    "Зона 3": {
      "desc": "Описание Зоны 3 в 2 абзаца...",
      "connections": ["Стартовая Зона"],
      "scripted_actions": []
    }
  }
}"""
	api.send_chat([{"role": "system", "content": architect_prompt}], tree, true)

func send_player_choice(choice_text: String, tree: SceneTree) -> void:
	active_generation_model = api.model_name
	pending_user_action = choice_text

	var cur_loc_data = quest.world_graph.get(quest.current_location, {})
	var conns_str = ", ".join(quest.get_connections()) if quest.get_connections().size() > 0 else "нет явных выходов"

	var p = quest.scenario_params
	var gm_prompt = """Ты — беспристрастный и талантливый Гейммастер настольной ролевой игры. Отвечай строго на языке повествования.
ТЕКУЩАЯ СИТУАЦИЯ:
- Локация: \"""" + quest.current_location + """\" (Этап: """ + quest.campaign_stage + """, Глава """ + str(quest.current_chapter) + """)
- Уровень сложности: """ + str(p.get("difficulty", "hard")) + """ (Пермасмерть: """ + str(p.get("permadeath", true)) + """)
- Заданная глубина головоломок: """ + str(p.get("puzzle_depth", "high")) + """
- Окружение: \"""" + str(cur_loc_data.get("desc", "")) + """\" (Выходы: """ + conns_str + """)
- Инвентарь игрока: """ + (", ".join(quest.inventory) if quest.inventory.size() > 0 else "пусто") + """
- Статы: """ + JSON.stringify(quest.stats) + """

ДЕЙСТВИЕ ИГРОКА: \"""" + choice_text + """\"

ПРАВИЛА МАСТЕРА:
1. Опиши реалистичные, веские последствия действия в 2 художественных абзацах ("narration"). Никаких односложных отписок!
2. Логика ставок:
   - Если действие глупое, шумное или безрассудное — накажи уроном ("damage_hp": 20-35) или гибелью ("is_ending": true, "victory": false, "ending_reason": "...").
   - Если действие смекалистое или использует окружение — вознагради ценной находкой ("inventory_add": ["ЧистоеИмя"]) или открытием нового прохода ("new_connections": ["ИмяКомнаты"]).
3. Если игрок потратил предмет из инвентаря — обязательно укажи его в "inventory_remove": ["ИмяПредмета"].
4. Если сейчас этап "climax" и игрок достиг финальной цели — присуди победу ("is_ending": true, "victory": true, "ending_reason": "...").
5. В "sub_actions" дай 1-2 мгновенных продолжения для выбранных действий, чтобы игрок мог действовать дальше без задержки.

ОТВЕТ СТРОГО В PURE JSON:
{
  \"narration\": \"Художественное описание последствий хода (2 абзаца)...\",
  \"damage_hp\": 0,
  \"stat_changes\": {},
  \"inventory_add\": [],
  \"inventory_remove\": [],
  \"new_connections\": [],
  \"is_ending\": false,
  \"victory\": false,
  \"ending_reason\": \"\",
  \"choices\": [{\"text\": \"Следующее логичное действие\", \"preview\": \"Краткая суть\"}],
  \"sub_actions\": [{\"text\": \"Следующее логичное действие\", \"narration\": \"Готовое продолжение...\"}]
}"""

	var messages = [{"role": "system", "content": gm_prompt}]
	for e in get_active_log().slice(-3):
		if e.get("action", "") != "": messages.append({"role": "user", "content": e["action"]})
		if e.get("narrative", "") != "": messages.append({"role": "assistant", "content": e["narrative"]})
	messages.append({"role": "user", "content": choice_text})

	api.send_chat(messages, tree, true)

func send_chat_message(text: String, tree: SceneTree) -> void:
	active_generation_model = api.model_name
	pending_user_action = text

	var messages = [{"role": "system", "content": "You are a helpful and intelligent AI assistant. Respond in the language of the user."}]
	for e in get_active_log().slice(-6):
		if e.get("action", "") != "": messages.append({"role": "user", "content": e["action"]})
		if e.get("narrative", "") != "": messages.append({"role": "assistant", "content": e["narrative"]})
	messages.append({"role": "user", "content": text})

	api.send_chat(messages, tree, false)

func handle_stream_completed(narrative: String, thinking: String, stats_data: Dictionary, setting_text: String) -> Dictionary:
	var used_model = active_generation_model if active_generation_model != "" else api.model_name
	var used_addr = api.base_url

	if current_mode == "game":
		game_tokens += stats_data.get("total_tokens", 0)
		if stats_data.has("prompt_tokens") and stats_data["prompt_tokens"] > 0: game_context_tokens = stats_data["prompt_tokens"]
	else:
		chat_tokens += stats_data.get("total_tokens", 0)
		if stats_data.has("prompt_tokens") and stats_data["prompt_tokens"] > 0: chat_context_tokens = stats_data["prompt_tokens"]

	if current_mode == "game" and not quest.is_game_active:
		var json = LLMJsonParser.extract_and_parse(narrative, "start_location")
		if json is Dictionary and json.has("start_location"):
			var start_loc = json["start_location"]
			var generated_graph = json.get("world_graph", {})

			if not generated_graph.has(start_loc):
				generated_graph[start_loc] = {
					"desc": json.get("narration", "..."),
					"connections": [],
					"scripted_actions": []
				}

			var raw_choices = json.get("choices", [])
			var initial_actions = []
			for c in raw_choices:
				if c is Dictionary:
					var c_text = c.get("text", "")
					var c_prev = c.get("preview", "Действие")
					var c_narr = c.get("narration", "")
					var c_inv = c.get("inventory_add", [])
					if c_text != "":
						initial_actions.append({
							"text": c_text, "preview": c_prev, "narration": c_narr,
							"inventory_add": c_inv, "once": true
						})

			generated_graph[start_loc]["scripted_actions"] = initial_actions

			quest.apply_generated_blueprint({
				"title": json.get("title", "Новая кампания"),
				"start_location": start_loc,
				"initial_stats": json.get("initial_stats", {"HP": 100, "Дни": 80}),
				"initial_inventory": json.get("initial_inventory", ["Записка"]),
				"world_graph": generated_graph
			}, setting_text)

			dynamic_game_choices = quest.generate_location_choices()
			add_story_entry("", json.get("narration", "..."), thinking, stats_data, "", used_model, used_addr)
			pending_user_action = ""
			choices_changed.emit()
			return {"blueprint_applied": true, "start_loc": start_loc}

	if current_mode == "game":
		var turn_json = LLMJsonParser.extract_and_parse(narrative, "narration")
		if turn_json is Dictionary:
			var res = quest.apply_turn_result(turn_json)
			var parsed_narr = turn_json.get("narration", narrative)
			if res.get("is_game_over", false):
				parsed_narr += GameStyle.format_game_over(res.get("victory", false), res.get("reason", "Кампания окончена."))

			var raw_c = turn_json.get("choices", [])
			dynamic_game_choices.clear()
			for item in raw_c:
				if item is Dictionary: dynamic_game_choices.append(item)
				elif item is String and item.strip_edges() != "": dynamic_game_choices.append({"text": item, "preview": ""})

			if dynamic_game_choices.size() == 0:
				dynamic_game_choices = quest.generate_location_choices()

			add_story_entry(pending_user_action, parsed_narr, thinking, stats_data, "", used_model, used_addr)
			pending_user_action = ""
			choices_changed.emit()
			return {"turn_applied": true}

	add_story_entry(pending_user_action, narrative, thinking, stats_data, "", used_model, used_addr)
	pending_user_action = ""
	return {"chat_applied": true}