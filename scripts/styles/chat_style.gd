class_name ChatStyle
extends RefCounted

static func format_user_message(text: String, font_size: int) -> String:
	return "[color=#4facfe][font_size=%d][b]Вы:[/b][/font_size][/color]\n[font_size=%d]%s[/font_size]\n\n" % [
		font_size + 1, font_size, text
	]

static func format_assistant_header(font_size: int) -> String:
	return "[color=#94a3b8][font_size=%d][b]Ассистент:[/b][/font_size][/color]\n" % [font_size]

static func get_thinking_style() -> String:
	return "[color=#94a3b8][font_size=13]"