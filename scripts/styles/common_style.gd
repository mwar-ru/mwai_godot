class_name CommonStyle
extends RefCounted

const COLOR_BG_PRIMARY   = Color("#121224")
const COLOR_BG_SECONDARY = Color("#1a1a35")
const COLOR_BG_TERTIARY  = Color("#1b2a4e")
const COLOR_BORDER       = Color("#2a2d4a")
const COLOR_ACCENT       = Color("#4facfe")
const COLOR_TEXT_PRIMARY = Color("#ffffff")
const COLOR_TEXT_MUTED   = Color("#94a3b8")

const COLOR_ITEM         = "#fbbf24"
const COLOR_LOCATION     = "#38bdf8"
const COLOR_CHARACTER    = "#c084fc"
const COLOR_DANGER       = "#f87171"

static var _regex_inited: bool = false
static var _re_item: RegEx
static var _re_loc: RegEx
static var _re_char: RegEx
static var _re_danger: RegEx

static func _ensure_regexes() -> void:
	if _regex_inited:
		return
	_regex_inited = true
	_re_item = RegEx.create_from_string("(?i)(?:\\[|<)(?:предмет|вещь|item)\\s*:\\s*([^\\]>]+)(?:\\]|>)")
	_re_loc = RegEx.create_from_string("(?i)(?:\\[|<)(?:локация|место|place)\\s*:\\s*([^\\]>]+)(?:\\]|>)")
	_re_char = RegEx.create_from_string("(?i)(?:\\[|<)(?:персонаж|npc|перс)\\s*:\\s*([^\\]>]+)(?:\\]|>)")
	_re_danger = RegEx.create_from_string("(?i)(?:\\[|<)(?:важно|опасность|danger|секрет|clue)\\s*:\\s*([^\\]>]+)(?:\\]|>)")

static func format_bbcode(text: String) -> String:
	_ensure_regexes()
	var res := text
	res = _re_item.sub(res, "[color=" + COLOR_ITEM + "][b]📦 $1[/b][/color]", true)
	res = _re_loc.sub(res, "[color=" + COLOR_LOCATION + "][b]📍 $1[/b][/color]", true)
	res = _re_char.sub(res, "[color=" + COLOR_CHARACTER + "][b]👤 $1[/b][/color]", true)
	res = _re_danger.sub(res, "[color=" + COLOR_DANGER + "][b]⚠️ $1[/b][/color]", true)
	return res

static func create_base_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 18

	th.set_font_size("font_size", "Button", 18)
	th.set_font_size("font_size", "LineEdit", 18)
	th.set_font_size("font_size", "TextEdit", 17)
	th.set_font_size("font_size", "OptionButton", 18)
	th.set_font_size("font_size", "PopupMenu", 18)
	th.set_font_size("font_size", "Label", 18)

	var sb_panel := StyleBoxFlat.new()
	sb_panel.bg_color = COLOR_BG_SECONDARY
	sb_panel.border_color = COLOR_BORDER
	sb_panel.set_border_width_all(1)
	sb_panel.set_corner_radius_all(8)
	sb_panel.content_margin_left = 12
	sb_panel.content_margin_right = 12
	sb_panel.content_margin_top = 10
	sb_panel.content_margin_bottom = 10
	th.set_stylebox("panel", "PanelContainer", sb_panel)

	var sb_btn_normal := StyleBoxFlat.new()
	sb_btn_normal.bg_color = COLOR_BG_TERTIARY
	sb_btn_normal.border_color = COLOR_BORDER
	sb_btn_normal.set_border_width_all(1)
	sb_btn_normal.set_corner_radius_all(6)
	sb_btn_normal.content_margin_left = 16
	sb_btn_normal.content_margin_right = 16
	sb_btn_normal.content_margin_top = 10
	sb_btn_normal.content_margin_bottom = 10
	th.set_stylebox("normal", "Button", sb_btn_normal)

	var sb_btn_hover := sb_btn_normal.duplicate()
	sb_btn_hover.bg_color = Color("#223868")
	sb_btn_hover.border_color = COLOR_ACCENT
	th.set_stylebox("hover", "Button", sb_btn_hover)

	var sb_input := StyleBoxFlat.new()
	sb_input.bg_color = Color("#0f1422")
	sb_input.border_color = COLOR_BORDER
	sb_input.set_border_width_all(1)
	sb_input.set_corner_radius_all(6)
	sb_input.content_margin_left = 14
	sb_input.content_margin_right = 14
	sb_input.content_margin_top = 10
	sb_input.content_margin_bottom = 10
	th.set_stylebox("normal", "LineEdit", sb_input)
	th.set_stylebox("normal", "TextEdit", sb_input)
	return th

static func _on_touch_gui_input(event: InputEvent, node: Variant) -> void:
	if event.get_class() == "InputEventScreenDrag":
		var rel = event.get("relative")
		if rel != null and rel is Vector2:
			var dy: float = rel.y
			if node.has_method("get_v_scroll_bar"):
				var sb = node.call("get_v_scroll_bar")
				if sb != null and sb.get("visible"):
					sb.set("value", sb.get("value") - dy)
			elif "scroll_vertical" in node:
				node.set("scroll_vertical", node.get("scroll_vertical") - dy)

static func enable_touch_scroll(node: Variant) -> void:
	if not (node is Control):
		return
	var ctrl: Control = node
	ctrl.gui_input.connect(_on_touch_gui_input.bind(node))