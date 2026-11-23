class_name UIBuilder
extends RefCounted

static func build(target: Control) -> Dictionary:
	var r: Dictionary = {}

	var root_margin = MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 8)
	root_margin.add_theme_constant_override("margin_top", 8)
	root_margin.add_theme_constant_override("margin_right", 8)
	root_margin.add_theme_constant_override("margin_bottom", 8)
	target.add_child(root_margin)
	r["root_margin"] = root_margin

	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 8)
	root_margin.add_child(root_vbox)
	r["root_vbox"] = root_vbox

	var mobile_top_row = HBoxContainer.new()
	mobile_top_row.add_theme_constant_override("separation", 8)
	mobile_top_row.visible = false
	root_vbox.add_child(mobile_top_row)
	r["mobile_top_row"] = mobile_top_row

	var desktop_split = HSplitContainer.new()
	desktop_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desktop_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(desktop_split)
	r["desktop_split"] = desktop_split

	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	r["left_vbox"] = left_vbox
	desktop_split.add_child(left_vbox)

	SmartBarBuilder.build(left_vbox, r)
	NarrativeWelcomeBuilder.build(left_vbox, r)
	InputStatusBuilder.build(left_vbox, r)
	RightPanelBuilder.build(desktop_split, r)

	CommonStyle.enable_touch_scroll(r["narrative_box"])

	return r