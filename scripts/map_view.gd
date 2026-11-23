class_name MapView
extends Control

signal location_selected(loc_name: String)

var graph_data: Dictionary = {}
var current_loc: String = "Камера"
var root_loc: String = ""
var visited_locs: Array = []
var revealed_locs: Array = []

var map_zoom: float = 1.0
var map_pan: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO

var node_positions: Dictionary = {}

func _ready() -> void:
	clip_contents = true

func update_data(graph: Dictionary, active_loc: String, visited: Array, revealed: Array) -> void:
	var graph_changed = (graph.keys() != graph_data.keys())
	graph_data = graph
	current_loc = active_loc
	visited_locs = visited
	revealed_locs = revealed

	# Рассчитываем координаты только при изменении структуры комнат, чтобы они не скакали при переходах
	if graph_changed or node_positions.size() == 0:
		if root_loc == "" or not graph_data.has(root_loc):
			root_loc = active_loc
		_calculate_stable_layout()

	queue_redraw()

# Фиксированная раскладка комнат: отсчёт всегда от постоянного корня root_loc
func _calculate_stable_layout() -> void:
	node_positions.clear()
	var locations = graph_data.keys()
	if locations.size() == 0: return

	var base_loc = root_loc if graph_data.has(root_loc) else locations[0]
	var visited_bfs: Array = [base_loc]
	var queue: Array = [{"name": base_loc, "pos": Vector2(250, 70)}]
	node_positions[base_loc] = Vector2(250, 70)

	while queue.size() > 0:
		var item = queue.pop_front()
		var parent_name = item["name"]
		var parent_pos = item["pos"]
		var conns = graph_data.get(parent_name, {}).get("connections", [])

		var unvisited_nbrs: Array = []
		for nbr in conns:
			if graph_data.has(nbr) and not visited_bfs.has(nbr):
				unvisited_nbrs.append(nbr)
				visited_bfs.append(nbr)

		var total_nbrs = unvisited_nbrs.size()
		for i in range(total_nbrs):
			var nbr_name = unvisited_nbrs[i]
			var offset: Vector2

			if total_nbrs == 1:
				offset = Vector2(0, 100)
			elif total_nbrs == 2:
				offset = Vector2(-135 if i == 0 else 135, 90)
			elif total_nbrs == 3:
				if i == 0: offset = Vector2(-150, 85)
				elif i == 1: offset = Vector2(0, 105)
				else: offset = Vector2(150, 85)
			else:
				var angle = (float(i) / float(max(1, total_nbrs - 1)) - 0.5) * PI * 0.85
				offset = Vector2(sin(angle) * 160.0, cos(angle) * 100.0)

			var nbr_pos = parent_pos + offset
			node_positions[nbr_name] = nbr_pos
			queue.append({"name": nbr_name, "pos": nbr_pos})

	var unplaced_idx = 0
	for loc in locations:
		if not node_positions.has(loc):
			node_positions[loc] = Vector2(100 + unplaced_idx * 160.0, 380)
			unplaced_idx += 1

func zoom_in() -> void:
	map_zoom = clamp(map_zoom + 0.15, 0.5, 2.5)
	queue_redraw()

func zoom_out() -> void:
	map_zoom = clamp(map_zoom - 0.15, 0.5, 2.5)
	queue_redraw()

func reset_view() -> void:
	map_pan = Vector2.ZERO
	map_zoom = 1.0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start = event.position - map_pan
			else:
				if is_dragging and (event.position - (drag_start + map_pan)).length() < 6.0:
					_handle_node_click(event.position)
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
	elif event is InputEventMouseMotion and is_dragging:
		map_pan = event.position - drag_start
		queue_redraw()

func _handle_node_click(click_pos: Vector2) -> void:
	var center = size / 2.0 + map_pan
	var min_dim = min(size.x, size.y)
	var scale_f = clamp(min_dim / 300.0, 0.7, 1.8) * map_zoom

	for loc in graph_data:
		var pos = node_positions.get(loc, Vector2(250, 70))
		var pt = (pos - Vector2(250, 70)) * scale_f + center
		if click_pos.distance_to(pt) <= 26.0 * scale_f:
			# Клик по текущей локации не инициирует повторный переход в себя
			if loc == current_loc:
				return

			var conns = graph_data.get(current_loc, {}).get("connections", [])
			if conns.has(loc):
				location_selected.emit(loc)
			return

func _draw() -> void:
	var center = size / 2.0 + map_pan
	var min_dim = min(size.x, size.y)
	var scale_f = clamp(min_dim / 300.0, 0.7, 1.8) * map_zoom

	# Линии связей
	for loc in graph_data:
		var pos = node_positions.get(loc, Vector2(250, 70))
		var start_pt = (pos - Vector2(250, 70)) * scale_f + center
		for conn in graph_data.get(loc, {}).get("connections", []):
			if graph_data.has(conn):
				var conn_pos = node_positions.get(conn, Vector2(250, 70))
				var end_pt = (conn_pos - Vector2(250, 70)) * scale_f + center
				var is_revealed = revealed_locs.has(loc) or visited_locs.has(loc)
				var line_col = Color("#38bdf8", 0.55) if is_revealed else Color("#1e293b", 0.35)
				draw_line(start_pt, end_pt, line_col, 2.8 * scale_f, true)

	# Узлы и центрированный текст без обрезки
	var font = ThemeDB.fallback_font
	var f_size = int(clamp(15.0 * scale_f, 12.0, 22.0))

	for loc in graph_data:
		var pos = node_positions.get(loc, Vector2(250, 70))
		var pt = (pos - Vector2(250, 70)) * scale_f + center
		var is_curr = (loc == current_loc)
		var is_rev = revealed_locs.has(loc) or visited_locs.has(loc)
		var node_data = graph_data.get(loc, {})

		var col = Color("#38bdf8") if is_curr else (Color("#1e293b") if is_rev else Color("#0d121f"))
		var border = Color("#ffffff") if is_curr else (Color("#475569") if is_rev else Color("#1f293d"))
		
		if is_rev and node_data.get("key_role") == "target":
			border = Color("#f87171")
		elif is_rev and node_data.get("key_role") == "key":
			border = Color("#fbbf24")

		draw_circle(pt, 20.0 * scale_f, col)
		draw_arc(pt, 20.0 * scale_f, 0, TAU, 32, border, 2.5, true)

		var title = loc if is_rev else "***"
		if is_curr: title = "📍 " + title
		elif is_rev and node_data.get("key_role") == "target": title = "🎯 " + title
		elif is_rev and node_data.get("key_role") == "key": title = "⚡ " + title

		# Динамический расчет ширины без жесткого лимита
		var text_sz = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size)
		var text_pos = pt + Vector2(-text_sz.x / 2.0, 26 * scale_f + text_sz.y / 2.0)
		var pad_rect = Rect2(text_pos.x - 4, text_pos.y - text_sz.y + 2, text_sz.x + 8, text_sz.y + 4)
		draw_rect(pad_rect, Color(0.06, 0.08, 0.14, 0.85), true)
		draw_string(font, text_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, Color.WHITE)