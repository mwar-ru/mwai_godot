class_name ApiClient
extends RefCounted

var base_url: String = "http://localhost:11434/v1"
var provider: String = "auto"
var auth_type: String = "auto"
var auth_token: String = ""
var model_name: String = "qwen2.5:latest"
var fast_mode: bool = true

const CONNECTION_TIMEOUT_SEC: float = 12.0
const REQUEST_TIMEOUT_SEC: float = 60.0

signal token_received(delta: String)
signal thinking_token_received(delta: String)
signal stream_status_changed(status_text: String, elapsed_sec: float, token_count: int)
signal stream_finished(narrative: String, thinking: String, stats: Dictionary)
signal stream_error(error_message: String)

func detect_provider() -> String:
	var host = base_url.to_lower()
	if "api.f5ai.ru" in host: return "f5ai"
	elif "api.anthropic.com" in host: return "anthropic"
	elif "generativelanguage.googleapis.com" in host: return "gemini"
	elif "openrouter.ai" in host: return "openai-compatible"
	elif "api.deepseek.com" in host: return "openai-compatible"
	elif "api.groq.com" in host: return "openai-compatible"
	elif "api.together.xyz" in host: return "openai-compatible"
	elif "api.mistral.ai" in host: return "openai-compatible"
	elif "api.openai.com" in host: return "openai"
	elif ":11434" in host or "ollama" in host: return "ollama"
	elif "localhost" in host or "127.0.0.1" in host or host.begins_with("http://192.168.") or host.begins_with("http://10.") or host.begins_with("http://172."):
		return "ollama"
	return "ollama"

func _parse_url(url: String) -> Dictionary:
	var clean = url.strip_edges()
	var is_ssl = clean.begins_with("https://")
	var without_proto = clean.replace("https://", "").replace("http://", "")
	var host_part = without_proto
	var path_prefix = ""
	var slash_pos = without_proto.find("/")
	if slash_pos != -1:
		host_part = without_proto.substr(0, slash_pos)
		path_prefix = without_proto.substr(slash_pos)
	path_prefix = path_prefix.rstrip("/")

	var host = host_part
	var port = 443 if is_ssl else 80
	if ":" in host_part:
		var p = host_part.split(":")
		host = p[0]
		port = int(p[1])
	elif not is_ssl and ("11434" in clean or host == "localhost"):
		port = 11434
	return {"is_ssl": is_ssl, "host": host, "port": port, "path_prefix": path_prefix}

func _get_tls_options(u: Dictionary) -> TLSOptions:
	if not u.is_ssl:
		return null
	var h = u.host.to_lower()
	if h == "localhost" or h == "127.0.0.1" or h.begins_with("192.168.") or h.begins_with("10.") or h.begins_with("172.") or h.ends_with(".local"):
		return TLSOptions.client_unsafe()
	return TLSOptions.client()

func _get_headers(active_provider: String) -> PackedStringArray:
	var h: Array[String] = [
		"Content-Type: application/json", "Accept: application/json",
		"User-Agent: Mozilla/5.0 mwar-AI-Playground/2.0"
	]
	var tok = auth_token.strip_edges()
	if tok != "":
		match active_provider:
			"anthropic":
				h.append("x-api-key: " + tok)
				h.append("anthropic-version: 2023-06-01")
			"gemini": pass
			"f5ai":
				h.append("X-Auth-Token: " + tok)
			_:
				h.append("Authorization: Bearer " + tok)
	return PackedStringArray(h)

func _extract_delta(json: Dictionary) -> Dictionary:
	var r_chunk = ""
	var c_chunk = ""
	if json.has("choices") and json["choices"].size() > 0:
		var delta_obj = json["choices"][0].get("delta", json["choices"][0].get("message", {}))
		r_chunk = delta_obj.get("reasoning_content", delta_obj.get("reasoning", ""))
		c_chunk = delta_obj.get("content", "")
	elif json.has("message"):
		var msg_obj = json["message"]
		if msg_obj is Dictionary:
			r_chunk = msg_obj.get("thinking", "")
			c_chunk = msg_obj.get("content", "")
		elif msg_obj is String:
			c_chunk = msg_obj
	elif json.has("response"):
		c_chunk = json["response"]
	elif json.has("candidates") and json["candidates"].size() > 0:
		var parts = json["candidates"][0].get("content", {}).get("parts", [])
		for p in parts: c_chunk += p.get("text", "")
	elif json.get("type") == "content_block_delta":
		c_chunk = json.get("delta", {}).get("text", "")
	return {"r": r_chunk, "c": c_chunk}

func _process_stream_chunk(json: Dictionary, req_fast_mode: bool, is_game: bool, state: Dictionary) -> void:
	state.stream_parsed_any = true
	var delta = _extract_delta(json)
	var r_chunk = delta.r
	var c_chunk = delta.c

	if r_chunk != "":
		state.is_in_reasoning_field = true
		state.thinking_tokens += int(ceil(r_chunk.length() / 3.0))
		if not req_fast_mode:
			state.thinking_text += r_chunk
			thinking_token_received.emit(r_chunk)

	if c_chunk != "":
		if state.is_in_reasoning_field:
			state.is_in_reasoning_field = false
			if state.thinking_end_time == 0: state.thinking_end_time = Time.get_ticks_msec()

		if state.content_start_time == 0 and not state.is_in_think_tag:
			state.content_start_time = Time.get_ticks_msec()

		if "<think>" in c_chunk:
			state.is_in_think_tag = true
			var parts = c_chunk.split("<think>", false, 1)
			c_chunk = parts[1] if parts.size() > 1 else ""

		if state.is_in_think_tag:
			if "</think>" in c_chunk:
				var parts = c_chunk.split("</think>", false, 1)
				var th_part = parts[0]
				var post_part = parts[1] if parts.size() > 1 else ""

				state.thinking_tokens += int(ceil(th_part.length() / 3.0))
				if not req_fast_mode:
					state.thinking_text += th_part
					thinking_token_received.emit(th_part)

				state.is_in_think_tag = false
				if state.thinking_end_time == 0: state.thinking_end_time = Time.get_ticks_msec()
				c_chunk = post_part
			else:
				state.thinking_tokens += int(ceil(c_chunk.length() / 3.0))
				if not req_fast_mode:
					state.thinking_text += c_chunk
					thinking_token_received.emit(c_chunk)
				c_chunk = ""

		if c_chunk != "":
			state.narrative_text += c_chunk
			state.content_tokens += int(ceil(c_chunk.length() / 3.0))
			if not is_game:
				token_received.emit(c_chunk)

	var usage = json.get("usage", {})
	if usage.has("prompt_tokens"): state.prompt_tokens = usage["prompt_tokens"]
	elif json.has("prompt_eval_count"): state.prompt_tokens = json["prompt_eval_count"]
	if json.has("eval_count"): state.content_tokens = json["eval_count"]

func send_chat(messages: Array, tree: SceneTree, is_game: bool = false) -> void:
	var req_fast_mode: bool = fast_mode
	var active_prov = detect_provider()
	var u = _parse_url(base_url)
	var client = HTTPClient.new()
	var err = client.connect_to_host(u.host, u.port, _get_tls_options(u))
	if err != OK:
		stream_error.emit("Ошибка подключения к %s:%d (код %d)" % [u.host, u.port, err])
		client.close()
		return

	var conn_start = Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		if (Time.get_ticks_msec() - conn_start) / 1000.0 > CONNECTION_TIMEOUT_SEC:
			stream_error.emit("Таймаут соединения с %s:%d" % [u.host, u.port])
			client.close()
			return
		await tree.process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		stream_error.emit("Сбой соединения с %s (Статус %d)" % [u.host, client.get_status()])
		client.close()
		return

	var endpoint = ""
	var payload_dict = {}
	var effective_msgs = messages.duplicate(true)

	if req_fast_mode:
		var sys_found = false
		for m in effective_msgs:
			if m.get("role") == "system":
				m["content"] = "/no_think\nRespond directly. Do not reason.\n" + m["content"]
				sys_found = true
				break
		if not sys_found:
			effective_msgs.insert(0, {"role": "system", "content": "/no_think\nRespond directly. Do not reason."})

	match active_prov:
		"ollama":
			var ollama_path = u.path_prefix.trim_suffix("/v1")
			endpoint = ollama_path + "/api/chat"
			payload_dict = {
				"model": model_name,
				"messages": effective_msgs,
				"stream": true,
				"options": {"temperature": 0.7, "num_ctx": 32768}
			}
			if req_fast_mode:
				payload_dict["think"] = false
				payload_dict["options"]["think"] = false
		"f5ai":
			endpoint = u.path_prefix + "/chat/completions"
			payload_dict = {
				"model": model_name,
				"messages": effective_msgs,
				"temperature": 0.7
			}
		"anthropic":
			endpoint = u.path_prefix + "/v1/messages"
			var system_prompt = ""
			var anth_msgs = []
			for m in effective_msgs:
				if m.get("role") == "system":
					system_prompt += m.get("content", "") + "\n"
				else:
					anth_msgs.append({"role": m.get("role", "user"), "content": m.get("content", "")})
			payload_dict = {
				"model": model_name,
				"messages": anth_msgs,
				"max_tokens": 4096,
				"stream": true
			}
			if system_prompt.strip_edges() != "":
				payload_dict["system"] = system_prompt.strip_edges()
		"gemini":
			endpoint = u.path_prefix + "/v1beta/models/" + model_name + ":streamGenerateContent?alt=sse"
			if auth_token.strip_edges() != "":
				endpoint += "&key=" + auth_token.strip_edges().uri_encode()
			var contents = []
			var sys_instruction = ""
			for m in effective_msgs:
				if m.get("role") == "system":
					sys_instruction += m.get("content", "") + "\n"
				else:
					var g_role = "model" if m.get("role") == "assistant" else "user"
					contents.append({"role": g_role, "parts": [{"text": m.get("content", "")}]})
			payload_dict = {"contents": contents, "generationConfig": {"temperature": 0.7}}
			if sys_instruction.strip_edges() != "":
				payload_dict["systemInstruction"] = {"parts": [{"text": sys_instruction.strip_edges()}]}
		_:
			endpoint = u.path_prefix + "/chat/completions"
			if not endpoint.begins_with("/"): endpoint = "/" + endpoint
			payload_dict = {
				"model": model_name,
				"messages": effective_msgs,
				"stream": true,
				"temperature": 0.7,
				"stream_options": {"include_usage": true}
			}
			if req_fast_mode:
				payload_dict["think"] = false

	err = client.request(HTTPClient.METHOD_POST, endpoint, _get_headers(active_prov), JSON.stringify(payload_dict))
	if err != OK:
		stream_error.emit("Ошибка запроса на %s (код %d)" % [endpoint, err])
		client.close()
		return

	var start_time = Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
		if elapsed > REQUEST_TIMEOUT_SEC:
			stream_error.emit("Таймаут ответа сервера (%.0fs)" % REQUEST_TIMEOUT_SEC)
			client.close()
			return
		var wait_text = "⏳ Ожидание ответа..." if not is_game else "⏳ Ожидание мастера..."
		stream_status_changed.emit(wait_text, elapsed, 0)
		await tree.process_frame

	var response_code = client.get_response_code()
	if response_code >= 400:
		var err_body = ""
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk = client.read_response_body_chunk()
			if chunk.size() > 0: err_body += chunk.get_string_from_utf8()
			await tree.process_frame
		client.close()
		stream_error.emit("HTTP %d от %s: %s" % [response_code, endpoint, err_body.strip_edges()])
		return

	var state = {
		"thinking_tokens": 0, "content_tokens": 0, "prompt_tokens": 0,
		"thinking_end_time": 0, "content_start_time": 0,
		"stream_parsed_any": false, "is_in_think_tag": false, "is_in_reasoning_field": false,
		"narrative_text": "", "thinking_text": ""
	}
	var raw_stream = ""
	var buffer = ""
	var last_chunk_time = Time.get_ticks_msec()

	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() > 0:
			last_chunk_time = Time.get_ticks_msec()
			var chunk_str = chunk.get_string_from_utf8()
			raw_stream += chunk_str
			buffer += chunk_str

			var lines = buffer.split("\n")
			buffer = lines[-1]

			for i in range(lines.size() - 1):
				var line = lines[i].strip_edges()
				if line == "" or line == "data: [DONE]" or line == "[DONE]":
					continue

				var raw_json = ""
				if line.begins_with("data:"): raw_json = line.substr(5).strip_edges()
				elif line.begins_with("{") and line.ends_with("}"): raw_json = line

				if raw_json == "" or raw_json == "[DONE]": continue

				var json = JSON.parse_string(raw_json)
				if json is Dictionary:
					_process_stream_chunk(json, req_fast_mode, is_game, state)

		var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
		var total_cur = state.thinking_tokens + state.content_tokens
		var is_thinking_now = state.is_in_reasoning_field or state.is_in_think_tag

		if total_cur == 0:
			var w_txt = "⏳ Ожидание ответа..." if not is_game else "⏳ Просчёт ситуации мастером..."
			stream_status_changed.emit(w_txt, elapsed, 0)
		elif is_thinking_now and not req_fast_mode:
			var th_txt = "💭 Размышление..." if not is_game else "💭 Мастер обдумывает ход..."
			stream_status_changed.emit(th_txt, elapsed, state.thinking_tokens)
		else:
			var ans_txt = "✍️ Печатает..." if not is_game else "✍️ Формирование сцены..."
			stream_status_changed.emit(ans_txt, elapsed, total_cur)

		if (Time.get_ticks_msec() - last_chunk_time) / 1000.0 > REQUEST_TIMEOUT_SEC:
			stream_error.emit("Таймаут ожидания потока данных (%.0fs)" % REQUEST_TIMEOUT_SEC)
			client.close()
			return
		await tree.process_frame

	client.close()

	if buffer.strip_edges() != "":
		var line = buffer.strip_edges()
		var raw_json = ""
		if line.begins_with("data:"): raw_json = line.substr(5).strip_edges()
		elif line.begins_with("{") and line.ends_with("}"): raw_json = line

		if raw_json != "" and raw_json != "[DONE]":
			var json = JSON.parse_string(raw_json)
			if json is Dictionary:
				_process_stream_chunk(json, req_fast_mode, is_game, state)

	if not state.stream_parsed_any and raw_stream.strip_edges() != "":
		var trimmed = raw_stream.strip_edges()
		if trimmed.begins_with("{") and trimmed.ends_with("}"):
			var json = JSON.parse_string(trimmed)
			if json is Dictionary:
				if json.has("error"):
					stream_error.emit("Ошибка API: " + str(json["error"]))
					return
				var extracted = _extract_delta(json).c
				if extracted == "" and json.has("choices") and json["choices"].size() > 0:
					extracted = json["choices"][0].get("message", {}).get("content", "")
				if extracted != "":
					state.narrative_text = extracted
					state.content_tokens = int(ceil(state.narrative_text.length() / 3.0))
					if not is_game: token_received.emit(state.narrative_text)
				var usage = json.get("usage", {})
				if usage.has("prompt_tokens"): state.prompt_tokens = usage["prompt_tokens"]

	var end_time = Time.get_ticks_msec()
	var total_sec = (end_time - start_time) / 1000.0

	var extracted_think = LLMJsonParser.extract_think_tag(state.narrative_text)
	if extracted_think != "":
		if not req_fast_mode and state.thinking_text == "":
			state.thinking_text = extracted_think
		state.narrative_text = LLMJsonParser.strip_think_tag(state.narrative_text)

	if req_fast_mode:
		state.thinking_text = ""
		state.thinking_tokens = 0

	if state.prompt_tokens == 0:
		for m in effective_msgs:
			state.prompt_tokens += int(ceil(str(m.get("content", "")).length() / 3.0))

	var thinking_sec = 0.0
	var content_sec = total_sec
	if state.thinking_tokens > 0:
		if state.thinking_end_time == 0: state.thinking_end_time = state.content_start_time if state.content_start_time > 0 else end_time
		thinking_sec = (state.thinking_end_time - start_time) / 1000.0
		content_sec = max(0.0, total_sec - thinking_sec)

	var total_tokens = state.thinking_tokens + state.content_tokens
	if total_tokens == 0 and state.narrative_text.strip_edges() != "":
		state.content_tokens = int(ceil(state.narrative_text.length() / 3.0))
		total_tokens = state.content_tokens

	var stats_dict = {
		"content_tokens": state.content_tokens, "content_time": content_sec,
		"thinking_tokens": state.thinking_tokens, "thinking_time": thinking_sec,
		"total_tokens": total_tokens, "total_time": total_sec, "prompt_tokens": state.prompt_tokens
	}
	stream_finished.emit(state.narrative_text.strip_edges(), state.thinking_text, stats_dict)

func send_chat_background_stream(messages: Array, tree: SceneTree, on_progress: Callable) -> Dictionary:
	var req_fast_mode: bool = fast_mode
	var active_prov = detect_provider()
	var u = _parse_url(base_url)
	var client = HTTPClient.new()
	var err = client.connect_to_host(u.host, u.port, _get_tls_options(u))
	if err != OK: 
		client.close()
		return {"error": "Connection error"}

	var conn_start = Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		if (Time.get_ticks_msec() - conn_start) / 1000.0 > CONNECTION_TIMEOUT_SEC:
			client.close()
			return {"error": "Connect timeout"}
		await tree.process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		client.close()
		return {"error": "Connect failed"}

	var effective_msgs = messages.duplicate(true)
	if req_fast_mode:
		var sys_found = false
		for m in effective_msgs:
			if m.get("role") == "system":
				m["content"] = "/no_think\nRespond directly. Do not reason.\n" + m["content"]
				sys_found = true
				break
		if not sys_found:
			effective_msgs.insert(0, {"role": "system", "content": "/no_think\nRespond directly. Do not reason."})

	var endpoint = u.path_prefix + "/chat/completions"
	var payload = {
		"model": model_name,
		"messages": effective_msgs,
		"temperature": 0.6
	}

	if req_fast_mode:
		payload["think"] = false

	if active_prov == "ollama":
		var ollama_path = u.path_prefix.trim_suffix("/v1")
		endpoint = ollama_path + "/api/chat"
		payload["stream"] = true
		if req_fast_mode:
			payload["options"] = {"think": false}
	elif active_prov != "f5ai":
		payload["stream"] = true

	err = client.request(HTTPClient.METHOD_POST, endpoint, _get_headers(active_prov), JSON.stringify(payload))
	if err != OK: 
		client.close()
		return {"error": "Request failed"}

	var start_time = Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
		if elapsed > REQUEST_TIMEOUT_SEC:
			client.close()
			return {"error": "Request timeout"}
		on_progress.call(elapsed, 0)
		await tree.process_frame

	var response_code = client.get_response_code()
	if response_code >= 400:
		var err_body = ""
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var err_chunk = client.read_response_body_chunk()
			if err_chunk.size() > 0: err_body += err_chunk.get_string_from_utf8()
			await tree.process_frame
		client.close()
		return {"error": "HTTP %d: %s" % [response_code, err_body.strip_edges()]}

	var full_text = ""
	var tokens = 0
	var buffer = ""
	var last_chunk_time = Time.get_ticks_msec()

	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() > 0:
			last_chunk_time = Time.get_ticks_msec()
			var s = chunk.get_string_from_utf8()
			buffer += s
			var lines = buffer.split("\n")
			buffer = lines[-1]
			for i in range(lines.size() - 1):
				var line = lines[i].strip_edges()
				if line == "" or line == "data: [DONE]" or line == "[DONE]": continue
				var raw_json = ""
				if line.begins_with("data:"): raw_json = line.substr(5).strip_edges()
				elif line.begins_with("{") and line.ends_with("}"): raw_json = line
				if raw_json == "" or raw_json == "[DONE]": continue

				var json = JSON.parse_string(raw_json)
				if json is Dictionary:
					var delta = _extract_delta(json).c
					if delta != "":
						full_text += delta
						tokens += int(ceil(delta.length() / 3.0))

		var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
		if (Time.get_ticks_msec() - last_chunk_time) / 1000.0 > REQUEST_TIMEOUT_SEC:
			client.close()
			return {"error": "Stream timeout"}
		on_progress.call(elapsed, tokens)
		await tree.process_frame

	client.close()

	if full_text == "" and buffer.strip_edges() != "":
		var trimmed = buffer.strip_edges()
		if trimmed.begins_with("{") and trimmed.ends_with("}"):
			var json = JSON.parse_string(trimmed)
			if json is Dictionary:
				full_text = _extract_delta(json).c
				if full_text == "" and json.has("choices") and json["choices"].size() > 0:
					full_text = json["choices"][0].get("message", {}).get("content", "")
				tokens = int(ceil(full_text.length() / 3.0))

	full_text = LLMJsonParser.strip_think_tag(full_text)
	return {"content": full_text, "tokens": tokens}

func fetch_models(tree: SceneTree) -> Dictionary:
	var active_prov = detect_provider()
	var u = _parse_url(base_url)
	var client = HTTPClient.new()
	var err = client.connect_to_host(u.host, u.port, _get_tls_options(u))
	if err != OK:
		client.close()
		return {"error": "Не удалось подключиться к %s:%d (код %d)" % [u.host, u.port, err]}

	var conn_start = Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		if (Time.get_ticks_msec() - conn_start) / 1000.0 > CONNECTION_TIMEOUT_SEC:
			client.close()
			return {"error": "Таймаут подключения к %s" % u.host}
		await tree.process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		client.close()
		return {"error": "Ошибка TCP/SSL соединения с %s" % u.host}

	var endpoints_to_try = []
	match active_prov:
		"ollama":
			var op = u.path_prefix.trim_suffix("/v1")
			endpoints_to_try.append(op + "/api/tags")
			endpoints_to_try.append(u.path_prefix + "/models")
		"f5ai":
			endpoints_to_try.append(u.path_prefix + "/models?type=llm")
			endpoints_to_try.append(u.path_prefix + "/models")
		"gemini":
			var ep = u.path_prefix + "/v1beta/models"
			if auth_token.strip_edges() != "": ep += "?key=" + auth_token.strip_edges().uri_encode()
			endpoints_to_try.append(ep)
		"anthropic":
			endpoints_to_try.append(u.path_prefix + "/v1/models?limit=1000")
		_:
			endpoints_to_try.append(u.path_prefix + "/models")
			endpoints_to_try.append(u.path_prefix + "/v1/models")
			endpoints_to_try.append("/v1/models")

	var response_body = ""
	var response_code = 0
	for ep in endpoints_to_try:
		err = client.request(HTTPClient.METHOD_GET, ep, _get_headers(active_prov))
		if err != OK: continue
		var req_start = Time.get_ticks_msec()
		while client.get_status() == HTTPClient.STATUS_REQUESTING:
			client.poll()
			if (Time.get_ticks_msec() - req_start) / 1000.0 > CONNECTION_TIMEOUT_SEC:
				client.close()
				return {"error": "Таймаут ответа от %s" % u.host}
			await tree.process_frame
		response_code = client.get_response_code()
		response_body = ""
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk = client.read_response_body_chunk()
			if chunk.size() > 0: response_body += chunk.get_string_from_utf8()
			await tree.process_frame
		if response_code == 200: break

	client.close()

	if response_code >= 400:
		return {"error": "HTTP %d от %s: %s" % [response_code, u.host, response_body.strip_edges()]}

	var json = JSON.parse_string(response_body)
	var raw_models = []
	if json is Array: raw_models = json
	elif json is Dictionary:
		raw_models = json.get("data", json.get("models", []))

	var list: Array[String] = []
	for m in raw_models:
		if m is Dictionary:
			var m_id = m.get("code", m.get("id", m.get("model", m.get("name", ""))))
			if m_id.begins_with("models/"): m_id = m_id.substr(7)
			if m_id != "": list.append(m_id)
		elif m is String:
			list.append(m)

	if list.size() == 0:
		return {"error": "Список моделей пуст"}
	return {"models": list}