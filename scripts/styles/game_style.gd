class_name GameStyle
extends RefCounted

static func create_choice_button_style() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#172033")
	sb.border_color = Color("#2e3e63")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

static func create_inventory_tag_style() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.75, 0.14, 0.15)
	sb.border_color = Color(0.98, 0.75, 0.14, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func format_player_action(text: String, font_size: int) -> String:
	return "[color=#38bdf8][font_size=%d]➤ %s[/font_size][/color]\n\n" % [font_size + 1, text]

static func format_game_over(is_victory: bool, reason: String) -> String:
	var title = "🏆 КАМПАНИЯ ЗАВЕРШЕНА: ПОБЕДА!" if is_victory else "💀 ПОРАЖЕНИЕ: ВЫ ПОГИБЛИ!"
	var color = "#2ecc71" if is_victory else "#f87171"
	return "\n[color=%s][font_size=22][b]%s[/b][/font_size][/color]\n[color=#cbd5e1]%s[/color]\n\n" % [
		color, title, reason
	]