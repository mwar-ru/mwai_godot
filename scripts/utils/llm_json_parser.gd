class_name LLMJsonParser
extends RefCounted

static var _regex_inited: bool = false
static var _re_think_clean: RegEx
static var _re_fence_clean: RegEx
static var _re_trailing_comma: RegEx
static var _re_clean_comma: RegEx
static var _re_think_tag_extract: RegEx

static func _ensure_static_regex() -> void:
	if _regex_inited: return
	_re_think_clean = RegEx.create_from_string("(?s)<think>.*?</think>")
	_re_fence_clean = RegEx.create_from_string("(?i)```(?:json)?|```")
	_re_trailing_comma = RegEx.create_from_string(",\\s*$")
	_re_clean_comma = RegEx.create_from_string(",\\s*([}\\]])")
	_re_think_tag_extract = RegEx.create_from_string("(?s)^\\s*<think>(.*?)</think>\\s*")
	_regex_inited = true

static func repair_and_close_json(raw: String) -> String:
	_ensure_static_regex()
	var in_str = false
	var esc = false
	var stack: Array[String] = []
	var res = ""

	for i in range(raw.length()):
		var c = raw[i]
		res += c
		if c == '"' and not esc:
			in_str = not in_str
		elif not in_str:
			if c == '{': stack.append("}")
			elif c == '[': stack.append("]")
			elif c == '}' or c == ']':
				if stack.size() > 0 and stack[-1] == c:
					stack.pop_back()
		esc = (c == '\\' and not esc)

	if in_str: res += '"'
	res = _re_trailing_comma.sub(res, "")

	while stack.size() > 0:
		res += stack.pop_back()
	return res

static func extract_and_parse(text: String, expected_key: String = "") -> Variant:
	if text.strip_edges() == "": return null
	_ensure_static_regex()
	var cleaned = text.strip_edges()

	cleaned = _re_think_clean.sub(cleaned, "", true).strip_edges()
	cleaned = _re_fence_clean.sub(cleaned, "", true).strip_edges()

	if not "{" in cleaned: return null

	var start_idx = -1
	if expected_key != "" and ('"' + expected_key + '"') in cleaned:
		var k_idx = cleaned.find('"' + expected_key + '"')
		start_idx = cleaned.rfind("{", k_idx)
	if start_idx == -1:
		start_idx = cleaned.find("{")

	if start_idx != -1:
		var candidate = cleaned.substr(start_idx)
		
		# 1. Попытка прямого парсинга чистого кандидата
		var direct_parse = JSON.parse_string(candidate)
		if direct_parse != null:
			return direct_parse

		# 2. Попытка починки и закрытия обрезанного JSON
		var repaired = repair_and_close_json(candidate)
		repaired = _re_clean_comma.sub(repaired, "$1", true)
		var parsed = JSON.parse_string(repaired)
		if parsed != null: 
			return parsed

		# 3. Эвристическая очистка: заменяем «ёлочки» и неэкранированные символы
		var sanitised = repaired.replace("«", "'").replace("»", "'").replace("“", "'").replace("”", "'")
		parsed = JSON.parse_string(sanitised)
		if parsed != null:
			return parsed

	# 4. Если ожидали world_graph, но сломался строгий JSON — собираем безопасный фоллбэк
	if expected_key == "world_graph" or '"world_graph"' in cleaned:
		var re_wg = RegEx.create_from_string('(?s)"world_graph"\\s*:\\s*\\{(.*)')
		var m_wg = re_wg.search(cleaned)
		if m_wg:
			var candidate_wg = "{" + m_wg.get_string(0)
			candidate_wg = repair_and_close_json(candidate_wg)
			var parsed_wg = JSON.parse_string(candidate_wg)
			if parsed_wg is Dictionary:
				return parsed_wg

	# 5. Фолбэк для пошагового ответа Гейммастера (narration, choices, inventory)
	var fb = {
		"narration": "",
		"choices": [],
		"inventory_add": [],
		"sub_actions": []
	}
	
	var re_narr = RegEx.create_from_string('(?s)"narration"\\s*:\\s*"([^"]+)"')
	var m_narr = re_narr.search(cleaned)
	if m_narr:
		fb["narration"] = m_narr.get_string(1).replace("\\n", "\n").replace('\\"', '"')
	else:
		fb["narration"] = cleaned

	var re_ch = RegEx.create_from_string('(?s)"choices"\\s*:\\s*(\\[.*?\\])')
	var m_ch = re_ch.search(cleaned)
	if m_ch:
		var p_ch = JSON.parse_string(m_ch.get_string(1))
		if p_ch is Array: fb["choices"] = p_ch

	var re_inv = RegEx.create_from_string('(?s)"inventory_add"\\s*:\\s*(\\[.*?\\])')
	var m_inv = re_inv.search(cleaned)
	if m_inv:
		var p_inv = JSON.parse_string(m_inv.get_string(1))
		if p_inv is Array: fb["inventory_add"] = p_inv

	return fb

static func extract_think_tag(text: String) -> String:
	_ensure_static_regex()
	var match = _re_think_tag_extract.search(text)
	return match.get_string(1).strip_edges() if match else ""

static func strip_think_tag(text: String) -> String:
	_ensure_static_regex()
	return _re_think_tag_extract.sub(text, "").strip_edges()