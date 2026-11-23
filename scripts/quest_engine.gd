class_name QuestEngine
extends RefCounted

var current_location: String = "Камера"
var current_act: int = 1
var current_chapter: int = 1
var campaign_stage: String = "intro" # "intro", "middle", "climax"
var active_campaign_title: String = "Тюрьма на планете Мацион"
var active_setting_text: String = ""

var scenario_params: Dictionary = {
	"difficulty": "hard",
	"acts": 3,
	"locations_count": 6,
	"choices_per_scene": 3,
	"narration_length": "rich",
	"endings_count": 3,
	"permadeath": true,
	"puzzle_depth": "high"
}
var is_game_active: bool = false
var is_game_over: bool = false

var inventory: Array = ["Записка"]
var stats: Dictionary = {"HP": 100, "Дни": 80}
var world_graph: Dictionary = {}
var visited_locations: Array = []
var revealed_locations: Array = []

var presets = QuestPresets.get_presets()

static func sanitize_item_name(raw: String) -> String:
	var s = raw.strip_edges()
	var re_tag = RegEx.create_from_string("(?i)^(?:\\[|<)(?:предмет|вещь|item)\\s*:\\s*([^\\]>]+)(?:\\]|>)$")
	var m = re_tag.search(s)
	if m:
		s = m.get_string(1).strip_edges()
	s = s.trim_prefix("[").trim_suffix("]").trim_prefix("<").trim_suffix(">").strip_edges()
	return s

func parse_scenario_params_from_text(text: String) -> void:
	var start_brace = text.find("{")
	var end_brace = text.rfind("}")
	if start_brace != -1 and end_brace != -1 and end_brace > start_brace:
		var json_str = text.substr(start_brace, end_brace - start_brace + 1)
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			for k in parsed:
				scenario_params[k] = parsed[k]

func apply_generated_blueprint(bp: Dictionary, setting_str: String) -> void:
	active_campaign_title = bp.get("title", "Пользовательский квест")
	active_setting_text = setting_str
	parse_scenario_params_from_text(setting_str)
	
	var initial_stats = bp.get("initial_stats", {})
	if initial_stats.size() == 0:
		stats = {"HP": 100}
		if setting_str.to_lower().contains("дней") or setting_str.to_lower().contains("мацион"):
			stats["Дни"] = 80
			stats["Кредиты"] = 200
			stats["Авторитет"] = 15
	else:
		stats = initial_stats.duplicate()

	inventory.clear()
	for it in bp.get("initial_inventory", ["Записка"]):
		var clean_it = sanitize_item_name(str(it))
		if clean_it != "" and not inventory.has(clean_it):
			inventory.append(clean_it)

	world_graph = bp.get("world_graph", {}).duplicate(true)
	
	for loc_name in world_graph:
		var node = world_graph[loc_name]
		if not node.has("connections"): node["connections"] = []
		if not node.has("scripted_actions"): node["scripted_actions"] = []
		if not node.has("desc") or str(node["desc"]).strip_edges() == "":
			node["desc"] = "Секция " + loc_name + ". Полутёмный коридор колонии, наполненный гулом вентиляции."
		
		for act in node["scripted_actions"]:
			if not act.has("repeatable") or not act["repeatable"]:
				act["once"] = true

	for loc_name in world_graph:
		for target in world_graph[loc_name].get("connections", []):
			if world_graph.has(target):
				if not world_graph[target]["connections"].has(loc_name):
					world_graph[target]["connections"].append(loc_name)

	current_location = bp.get("start_location", world_graph.keys()[0] if world_graph.size() > 0 else "Старт")
	current_act = 1
	is_game_over = false
	is_game_active = true

	visited_locations = [current_location]
	revealed_locations = [current_location]
	for c in world_graph.get(current_location, {}).get("connections", []):
		if not revealed_locations.has(c): revealed_locations.append(c)

func get_connections() -> Array:
	return world_graph.get(current_location, {}).get("connections", [])

func get_scripted_actions() -> Array:
	var raw_actions = world_graph.get(current_location, {}).get("scripted_actions", [])
	var filtered: Array = []
	var seen_texts: Array[String] = []

	for act in raw_actions:
		if act.get("completed", false):
			continue
		var act_text = str(act.get("text", "")).strip_edges().to_lower()
		if act_text == "" or seen_texts.has(act_text):
			continue
		seen_texts.append(act_text)
		filtered.append(act)

	return filtered

func generate_location_choices() -> Array:
	var list: Array = []
	var seen_choices: Array[String] = []

	for act in get_scripted_actions():
		var t = act.get("text", "").strip_edges()
		if t != "" and not seen_choices.has(t.to_lower()):
			seen_choices.append(t.to_lower())
			list.append({"text": t, "preview": act.get("preview", "Исследовать")})

	for conn in get_connections():
		var conn_str = "Перейти в " + conn
		if not seen_choices.has(conn_str.to_lower()):
			seen_choices.append(conn_str.to_lower())
			list.append({"text": conn_str, "preview": "Направиться в " + conn})
	
	if list.size() == 0:
		list.append({"text": "Тщательно обыскать сектор", "preview": "Поиск лазов и тайников"})
		list.append({"text": "Прислушаться к окружению", "preview": "Оценить обстановку"})
		list.append({"text": "Проверить вентиляционные решетки", "preview": "Искать путь дальше"})

	return list

func tick_time(days_spent: int = 1) -> Dictionary:
	if stats.has("Дни"):
		stats["Дни"] = max(0, int(stats["Дни"]) - days_spent)
		if stats["Дни"] <= 0:
			is_game_over = true
			return {"is_game_over": true, "victory": false, "reason": "Срок заключения истёк, либо ваше время вышло. Режим колонии не оставил шансов."}
	elif stats.has("Кислород"):
		stats["Кислород"] = max(0, int(stats["Кислород"]) - days_spent)
		if stats["Кислород"] <= 0:
			is_game_over = true
			return {"is_game_over": true, "victory": false, "reason": "Запас кислорода в скафандре полностью исчерпан."}
	return {"is_game_over": false}

func try_move(target_loc: String) -> Dictionary:
	if not world_graph.has(target_loc):
		world_graph[target_loc] = {
			"desc": "Секция [локация: " + target_loc + "]. Вы проходите через створку шлюза в неизведанную часть комплекса. Вокруг гудят кабели питания и мерцают аварийные лампы.",
			"connections": [current_location],
			"scripted_actions": []
		}

	var target = world_graph[target_loc]
	if not target.has("connections"): target["connections"] = []
	if not target.has("scripted_actions"): target["scripted_actions"] = []
	
	if target.get("locked", false):
		var req = target.get("requires", "")
		if req != "" and not inventory.has(req):
			return {"success": false, "narration": target.get("lock_message", "Проход в [%s] закрыт!" % target_loc)}
		
		if target.get("consume_item", true) and req != "":
			inventory.erase(req)
		target["locked"] = false

	var prev_loc = current_location
	current_location = target_loc

	if not world_graph.has(current_location):
		world_graph[current_location] = {
			"desc": "Секция " + current_location + ".",
			"connections": [prev_loc],
			"scripted_actions": []
		}
	elif not world_graph[current_location].get("connections", []).has(prev_loc):
		world_graph[current_location]["connections"].append(prev_loc)

	if not visited_locations.has(target_loc): visited_locations.append(target_loc)
	if not revealed_locations.has(target_loc): revealed_locations.append(target_loc)
	for c in world_graph[current_location].get("connections", []):
		if not revealed_locations.has(c): revealed_locations.append(c)

	var time_res = tick_time(1)
	if time_res.get("is_game_over", false):
		return {"success": true, "narration": "Вы переходите в [локация: " + target_loc + "].\n\nВремя вышло!", "is_ending": true, "victory": false}

	var desc = str(world_graph[current_location].get("desc", "")).strip_edges()
	if desc == "":
		desc = "Вы вступаете под своды сектора [локация: %s]. Вокруг царит полутьма и напряженная тишина." % target_loc
		world_graph[current_location]["desc"] = desc

	var move_text = "Вы переходите в [локация: " + target_loc + "].\n\n" + desc

	if target.get("is_ending", false):
		is_game_over = true
		return {"success": true, "narration": move_text, "is_ending": true, "victory": target.get("victory", false)}

	return {"success": true, "narration": move_text, "is_ending": false}

func execute_action(action_text: String) -> Dictionary:
	var loc_data = world_graph.get(current_location, {})
	var norm_action = action_text.strip_edges().to_lower()

	for act in loc_data.get("scripted_actions", []):
		if act.get("completed", false):
			continue
		var norm_act_text = str(act.get("text", "")).strip_edges().to_lower()

		if norm_act_text == norm_action or norm_act_text in norm_action:
			var narr = str(act.get("narration", "")).strip_edges()
			if narr == "" or narr.contains("Обстановка вокруг"):
				return {"found": false}

			var req = act.get("requires", "")
			if req != "" and not inventory.has(req):
				return {"found": true, "narration": "Требуется [предмет: %s]!" % req, "is_ending": false}

			if req != "" and act.get("consume_item", true):
				inventory.erase(req)

			for del_it in act.get("inventory_remove", []):
				var clean_del = sanitize_item_name(str(del_it))
				if inventory.has(clean_del):
					inventory.erase(clean_del)

			if not act.get("repeatable", false):
				act["completed"] = true
				act["once"] = true
			
			for item in act.get("inventory_add", []):
				var clean_item = sanitize_item_name(str(item))
				if clean_item != "" and not inventory.has(clean_item):
					inventory.append(clean_item)

			if act.get("new_location", "") != "" and world_graph.has(act["new_location"]):
				try_move(act["new_location"])

			if act.get("is_ending", false):
				is_game_over = true
				return {"found": true, "narration": narr, "is_ending": true, "victory": act.get("victory", false)}

			return {"found": true, "narration": narr, "is_ending": false}
	return {"found": false}

func apply_turn_result(turn_data: Dictionary) -> Dictionary:
	if turn_data.get("is_ending", false):
		is_game_over = true
		return {
			"is_game_over": true,
			"victory": turn_data.get("victory", false),
			"reason": turn_data.get("ending_reason", "Ваш путь в этом мире подошел к концу.")
		}

	var damage = int(turn_data.get("damage_hp", 0))
	if damage > 0 and stats.has("HP"):
		stats["HP"] = max(0, stats["HP"] - damage)
		if stats["HP"] <= 0:
			is_game_over = true
			return {"is_game_over": true, "victory": false, "reason": "Полученные травмы оказались несовместимы с жизнью."}

	var stat_changes = turn_data.get("stat_changes", {})
	if stat_changes is Dictionary:
		for k in stat_changes:
			if stats.has(k) and stats[k] is int:
				stats[k] += int(stat_changes[k])
			else:
				stats[k] = stat_changes[k]

	var items_to_remove = turn_data.get("inventory_remove", [])
	if items_to_remove is Array:
		for it in items_to_remove:
			var clean_del = sanitize_item_name(str(it))
			inventory.erase(clean_del)

	var items_to_add = turn_data.get("inventory_add", [])
	if items_to_add is Array:
		for item in items_to_add:
			var clean = sanitize_item_name(str(item))
			if clean != "" and not inventory.has(clean):
				inventory.append(clean)

	var sub_acts = turn_data.get("sub_actions", [])
	if sub_acts is Array:
		var cur_node = world_graph.get(current_location, {})
		if not cur_node.has("scripted_actions"): cur_node["scripted_actions"] = []
		
		var existing_texts: Array[String] = []
		for ea in cur_node["scripted_actions"]:
			existing_texts.append(str(ea.get("text", "")).strip_edges().to_lower())

		for sub in sub_acts:
			if sub is Dictionary and sub.has("text") and sub.has("narration"):
				var sub_t = str(sub["text"]).strip_edges()
				if not existing_texts.has(sub_t.to_lower()):
					existing_texts.append(sub_t.to_lower())
					cur_node["scripted_actions"].insert(0, {
						"text": sub_t,
						"preview": sub.get("preview", "Действие"),
						"narration": sub["narration"],
						"inventory_add": sub.get("inventory_add", []),
						"inventory_remove": sub.get("inventory_remove", []),
						"consume_item": sub.get("consume_item", true),
						"requires": sub.get("requires", ""),
						"once": true,
						"completed": false,
						"is_ending": sub.get("is_ending", false),
						"victory": sub.get("victory", false)
					})

	var new_conns = turn_data.get("new_connections", [])
	if new_conns is Array and new_conns.size() > 0:
		var cur_conns = world_graph.get(current_location, {}).get("connections", [])
		for nc in new_conns:
			var sc = str(nc).strip_edges()
			if sc != "" and not cur_conns.has(sc):
				cur_conns.append(sc)
				if not revealed_locations.has(sc): revealed_locations.append(sc)
				if not world_graph.has(sc):
					world_graph[sc] = {
						"desc": "Секция " + sc + ". Обнаруженное вами новое ответвление коридоров.",
						"connections": [current_location],
						"scripted_actions": []
					}

	return {"is_game_over": is_game_over}

func should_expand_world() -> bool:
	if not is_game_active or is_game_over: return false
	if campaign_stage == "climax": return false
	
	var total_acts = int(scenario_params.get("acts", 3))
	if current_act >= total_acts:
		campaign_stage = "climax"
		return true

	var conns = get_connections()
	var unvisited_count = 0
	for loc in revealed_locations:
		if not visited_locations.has(loc): unvisited_count += 1
	return conns.size() <= 1 or unvisited_count <= 1

func expand_act_in_background(api_client: ApiClient, tree: SceneTree, on_progress: Callable, on_complete: Callable) -> void:
	var total_acts = int(scenario_params.get("acts", 3))
	var mid_chapters_target = max(1, total_acts - 2)

	if campaign_stage == "intro":
		if total_acts <= 2:
			campaign_stage = "climax"
		else:
			campaign_stage = "middle"
			current_chapter = 1
	elif campaign_stage == "middle":
		current_chapter += 1
		if current_chapter >= mid_chapters_target:
			campaign_stage = "climax"

	var prompt = QuestGenerator.build_expansion_prompt(self)
	var res = await api_client.send_chat_background_stream([{"role": "system", "content": prompt}], tree, on_progress)
	
	if res.has("content") and str(res["content"]).strip_edges() != "":
		var parsed = LLMJsonParser.extract_and_parse(res["content"], "world_graph")
		if parsed is Dictionary and parsed.has("world_graph") and parsed["world_graph"] is Dictionary:
			for loc_name in parsed["world_graph"]:
				var loc_obj = parsed["world_graph"][loc_name]
				if not (loc_obj is Dictionary): continue
				if not world_graph.has(loc_name):
					world_graph[loc_name] = loc_obj
				else:
					for c in loc_obj.get("connections", []):
						if not world_graph[loc_name].get("connections", []).has(c):
							world_graph[loc_name]["connections"].append(c)
					for act in loc_obj.get("scripted_actions", []):
						act["once"] = true
						world_graph[loc_name]["scripted_actions"].append(act)

			for l in world_graph:
				for c in world_graph[l].get("connections", []):
					if world_graph.has(c) and not world_graph[c]["connections"].has(l):
						world_graph[c]["connections"].append(l)

			for c in world_graph.get(current_location, {}).get("connections", []):
				if not revealed_locations.has(c): revealed_locations.append(c)
			on_complete.call(true, res.get("tokens", 0))
			return
	on_complete.call(false, 0)

func export_quest_file() -> String:
	var downloads_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var base_folder = downloads_dir + "/mwai_playground/saved_quests"
	DirAccess.make_dir_recursive_absolute(base_folder)

	var safe_title = active_campaign_title.replace(" ", "_").replace("'", "")
	var file_name = "quest_" + safe_title + "_" + str(int(Time.get_unix_time_from_system())) + ".json"
	var full_path = base_folder + "/" + file_name

	var data = {
		"title": active_campaign_title,
		"start_location": current_location,
		"initial_stats": stats,
		"initial_inventory": inventory,
		"world_graph": world_graph,
		"acts_total": current_act
	}

	var f = FileAccess.open(full_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		return full_path
	return ""