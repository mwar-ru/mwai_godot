class_name SessionManager
extends RefCounted

const ApiClient = preload("res://scripts/api_client.gd")
const QuestEngine = preload("res://scripts/quest_engine.gd")

const AUTO_SAVE_PATH = "user://last_session.json"

var file_dialog: FileDialog
var session_file_dialog: FileDialog
var parent_control: Control

signal quest_blueprint_loaded(blueprint: Dictionary)
signal session_loaded(data: Dictionary)
signal sandbox_game_loaded(data: Dictionary)
signal toast_requested(message: String)

func _init(parent: Control) -> void:
	parent_control = parent
	_build_dialogs()

func _build_dialogs() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.json ; JSON Files"]
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	file_dialog.file_selected.connect(_on_quest_file_selected)
	parent_control.add_child(file_dialog)

	session_file_dialog = FileDialog.new()
	session_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	session_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	session_file_dialog.filters = ["*.json ; JSON Session"]
	session_file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	session_file_dialog.file_selected.connect(_on_session_file_selected)
	parent_control.add_child(session_file_dialog)

func open_quest_picker() -> void:
	file_dialog.popup_centered(Vector2(700, 500))

func open_session_picker() -> void:
	session_file_dialog.popup_centered(Vector2(700, 500))

func _on_quest_file_selected(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return
	var json = JSON.parse_string(f.get_as_text())
	if json is Dictionary:
		if json.get("type") == "sandbox_game" or json.has("sandbox_code"):
			sandbox_game_loaded.emit(json)
		elif json.has("world_graph"):
			quest_blueprint_loaded.emit(json)

func _on_session_file_selected(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return
	var json = JSON.parse_string(f.get_as_text())
	if json is Dictionary and json.has("config"):
		session_loaded.emit(json)

func has_auto_save() -> bool:
	return FileAccess.file_exists(AUTO_SAVE_PATH)

func load_auto_save() -> Dictionary:
	if not has_auto_save():
		return {}
	var f = FileAccess.open(AUTO_SAVE_PATH, FileAccess.READ)
	if not f:
		return {}
	var json = JSON.parse_string(f.get_as_text())
	if json is Dictionary:
		return json
	return {}

func auto_save(current_mode: String, story_controller, quest: QuestEngine, api: ApiClient, pending_task: Dictionary = {}) -> void:
	var data = {
		"version": 2,
		"savedAt": Time.get_datetime_string_from_system(),
		"mode": current_mode,
		"chat_story_log": story_controller.chat_story_log,
		"game_story_log": story_controller.game_story_log,
		"dynamic_game_choices": story_controller.dynamic_game_choices,
		"tokens": {
			"game_tokens": story_controller.game_tokens,
			"chat_tokens": story_controller.chat_tokens,
			"game_context_tokens": story_controller.game_context_tokens,
			"chat_context_tokens": story_controller.chat_context_tokens
		},
		"gameState": {
			"active": quest.is_game_active,
			"is_game_over": quest.is_game_over,
			"currentLocation": quest.current_location,
			"inventory": quest.inventory,
			"stats": quest.stats,
			"world_graph": quest.world_graph,
			"visited": quest.visited_locations,
			"revealed": quest.revealed_locations,
			"title": quest.active_campaign_title,
			"setting": quest.active_setting_text,
			"act": quest.current_act
		},
		"pending_generation": pending_task
	}
	var f = FileAccess.open(AUTO_SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))

func export_session(current_mode: String, active_log: Array, quest: QuestEngine, api: ApiClient) -> void:
	var downloads_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var subfolder = "context_quest" if current_mode == "game" else "context_chat"
	var base_folder = downloads_dir + "/mwai_playground/" + subfolder
	DirAccess.make_dir_recursive_absolute(base_folder)

	var file_name = subfolder + "_" + str(int(Time.get_unix_time_from_system())) + ".json"
	var full_path = base_folder + "/" + file_name

	var data = {
		"version": 2,
		"exportedAt": Time.get_datetime_string_from_system(),
		"config": {
			"address": api.base_url,
			"provider": api.provider,
			"authType": api.auth_type,
			"token": "",
			"model": api.model_name
		},
		"mode": current_mode,
		"messages": active_log,
		"gameState": {
			"active": quest.is_game_active,
			"currentLocation": quest.current_location,
			"inventory": quest.inventory,
			"stats": quest.stats,
			"world_graph": quest.world_graph,
			"visited": quest.visited_locations,
			"revealed": quest.revealed_locations,
			"title": quest.active_campaign_title
		}
	}

	var f = FileAccess.open(full_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		toast_requested.emit("💾 Сессия сохранена в:\n" + full_path)