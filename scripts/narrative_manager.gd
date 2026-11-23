class_name NarrativeManager
extends RefCounted

const CommonStyle = preload("res://scripts/styles/common_style.gd")
const ChatStyle = preload("res://scripts/styles/chat_style.gd")
const GameStyle = preload("res://scripts/styles/game_style.gd")

static func render_log(narrative_box: RichTextLabel, log_arr: Array, current_mode: String, current_font_size: int) -> void:
	narrative_box.clear()
	for i in range(log_arr.size()):
		var e = log_arr[i]
		if e.get("action", "") != "":
			if current_mode == "game":
				narrative_box.append_text(GameStyle.format_player_action(e["action"], current_font_size))
			else:
				narrative_box.append_text(ChatStyle.format_user_message(e["action"], current_font_size))

		var formatted_narrative = CommonStyle.format_bbcode(e.get("narrative", ""))
		var asst_prefix = "" if current_mode == "game" else ChatStyle.format_assistant_header(current_font_size)
		narrative_box.append_text(asst_prefix + formatted_narrative + "\n\n")

		var meta_line = ""
		var saved_model = e.get("model", "")
		var saved_addr = e.get("address", "")
		var addr_badge = (" (" + saved_addr + ")") if saved_addr != "" else ""

		if e.get("stats", {}).size() > 0:
			var st = e["stats"]
			var think_badge = ""
			if e.get("thinking", "") != "":
				var arrow = "▲" if e.get("thinking_expanded", false) else "▼"
				think_badge = " ( [url=toggle_think_%d][color=#4facfe]💭 %.1fs | 🔢 %d tok %s[/color][/url] )" % [
					i,
					st.get("thinking_time", 0.0),
					st.get("thinking_tokens", 0),
					arrow
				]
			meta_line = "🤖 %s%s | ⏱️ %.1fs | 🔢 %d tok%s" % [
				saved_model,
				addr_badge,
				st.get("content_time", 0.0),
				st.get("content_tokens", 0),
				think_badge
			]
		elif e.get("meta", "") != "":
			meta_line = e["meta"]

		if meta_line != "":
			narrative_box.append_text("[color=#64748b][font_size=%d]%s[/font_size][/color]\n\n" % [max(12, current_font_size - 3), meta_line])

		if e.get("thinking", "") != "" and e.get("thinking_expanded", false):
			narrative_box.append_text(
				"[color=#94a3b8][font_size=%d]┌── 💭 Ход мыслей:\n%s\n└── [/font_size][/color]" % [max(13, current_font_size - 2), e["thinking"]] +
				"[url=toggle_think_%d][color=#4facfe][font_size=%d]▲ Свернуть[/font_size][/color][/url]\n\n" % [i, max(12, current_font_size - 3)]
			)

		# Всегда резервируем дополнительную пустую строку в самом конце последней записи ленты
		if i == log_arr.size() - 1:
			narrative_box.append_text("\n")