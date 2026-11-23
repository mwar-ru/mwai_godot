class_name ThemeManager
extends RefCounted

static func create_theme() -> Theme:
	var th = Theme.new()
	
	# Панели
	var sb_panel = StyleBoxFlat.new()
	sb_panel.bg_color = Color("#1a1a35"); sb_panel.border_color = Color("#2a2d4a")
	sb_panel.set_border_width_all(1); sb_panel.set_corner_radius_all(6)
	sb_panel.content_margin_left = 10; sb_panel.content_margin_right = 10
	sb_panel.content_margin_top = 8; sb_panel.content_margin_bottom = 8
	th.set_stylebox("panel", "PanelContainer", sb_panel)

	# Кнопки
	var sb_btn_normal = StyleBoxFlat.new()
	sb_btn_normal.bg_color = Color("#1b2a4e"); sb_btn_normal.border_color = Color("#2a2d4a")
	sb_btn_normal.set_border_width_all(1); sb_btn_normal.set_corner_radius_all(6)
	sb_btn_normal.content_margin_left = 10; sb_btn_normal.content_margin_right = 10
	sb_btn_normal.content_margin_top = 6; sb_btn_normal.content_margin_bottom = 6
	th.set_stylebox("normal", "Button", sb_btn_normal)

	var sb_btn_hover = sb_btn_normal.duplicate()
	sb_btn_hover.bg_color = Color("#223868"); sb_btn_hover.border_color = Color("#4facfe")
	th.set_stylebox("hover", "Button", sb_btn_hover)

	# Поля ввода
	var sb_input = StyleBoxFlat.new()
	sb_input.bg_color = Color("#0f1422"); sb_input.border_color = Color("#2a2d4a")
	sb_input.set_border_width_all(1); sb_input.set_corner_radius_all(6)
	sb_input.content_margin_left = 10; sb_input.content_margin_right = 10
	sb_input.content_margin_top = 8; sb_input.content_margin_bottom = 8
	th.set_stylebox("normal", "LineEdit", sb_input)
	th.set_stylebox("normal", "TextEdit", sb_input)
	return th