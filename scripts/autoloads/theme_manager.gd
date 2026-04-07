extends Node
## Creates and manages the dark medieval UI theme for the entire game.
## Add as autoload to apply theme globally.

var theme: Theme


func _ready() -> void:
	theme = _create_medieval_theme()
	# Apply to all existing and future UI
	get_tree().root.theme = theme


func _create_medieval_theme() -> Theme:
	var t := Theme.new()

	# Colors
	var gold := Color(0.85, 0.75, 0.55)
	var dark_bg := Color(0.06, 0.05, 0.08)
	var panel_bg := Color(0.08, 0.07, 0.1, 0.95)
	var button_normal := Color(0.12, 0.1, 0.15)
	var button_hover := Color(0.18, 0.15, 0.22)
	var button_pressed := Color(0.25, 0.2, 0.12)
	var button_disabled := Color(0.08, 0.07, 0.09)
	var text_normal := Color(0.8, 0.75, 0.7)
	var text_dim := Color(0.5, 0.45, 0.4)
	var separator_color := Color(0.2, 0.18, 0.15)
	var border_color := Color(0.3, 0.25, 0.18)

	# === Button ===
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = button_normal
	btn_normal.border_color = border_color
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(4)
	btn_normal.set_content_margin_all(12)

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = button_hover
	btn_hover.border_color = gold

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = button_pressed
	btn_pressed.border_color = gold

	var btn_disabled := btn_normal.duplicate()
	btn_disabled.bg_color = button_disabled
	btn_disabled.border_color = Color(0.15, 0.12, 0.1)

	var btn_focus := btn_normal.duplicate()
	btn_focus.border_color = gold
	btn_focus.set_border_width_all(3)

	t.set_stylebox("normal", "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("disabled", "Button", btn_disabled)
	t.set_stylebox("focus", "Button", btn_focus)
	t.set_color("font_color", "Button", text_normal)
	t.set_color("font_hover_color", "Button", gold)
	t.set_color("font_pressed_color", "Button", Color(1, 0.9, 0.6))
	t.set_color("font_disabled_color", "Button", text_dim)
	t.set_font_size("font_size", "Button", 18)

	# === Label ===
	t.set_color("font_color", "Label", text_normal)
	t.set_font_size("font_size", "Label", 16)

	# === LineEdit ===
	var le_normal := StyleBoxFlat.new()
	le_normal.bg_color = Color(0.04, 0.03, 0.06)
	le_normal.border_color = border_color
	le_normal.set_border_width_all(1)
	le_normal.set_corner_radius_all(3)
	le_normal.set_content_margin_all(8)

	var le_focus := le_normal.duplicate()
	le_focus.border_color = gold
	le_focus.set_border_width_all(2)

	t.set_stylebox("normal", "LineEdit", le_normal)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", text_normal)
	t.set_color("font_placeholder_color", "LineEdit", text_dim)
	t.set_color("caret_color", "LineEdit", gold)

	# === Panel ===
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel_bg
	panel_style.border_color = border_color
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(16)
	t.set_stylebox("panel", "Panel", panel_style)
	t.set_stylebox("panel", "PanelContainer", panel_style)

	# === CheckButton ===
	t.set_color("font_color", "CheckButton", text_normal)
	t.set_color("font_hover_color", "CheckButton", gold)

	# === OptionButton ===
	t.set_stylebox("normal", "OptionButton", btn_normal.duplicate())
	t.set_stylebox("hover", "OptionButton", btn_hover.duplicate())
	t.set_stylebox("pressed", "OptionButton", btn_pressed.duplicate())
	t.set_stylebox("focus", "OptionButton", btn_focus.duplicate())
	t.set_color("font_color", "OptionButton", text_normal)
	t.set_color("font_hover_color", "OptionButton", gold)

	# === HSlider ===
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.1, 0.08, 0.12)
	slider_bg.set_content_margin_all(4)
	slider_bg.set_corner_radius_all(3)
	t.set_stylebox("slider", "HSlider", slider_bg)

	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = Color(0.6, 0.5, 0.3)
	slider_fill.set_corner_radius_all(3)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)

	# === HSeparator ===
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = separator_color
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 4
	sep_style.content_margin_bottom = 4
	t.set_stylebox("separator", "HSeparator", sep_style)

	# === RichTextLabel ===
	t.set_color("default_color", "RichTextLabel", text_normal)

	# === PopupMenu (for OptionButton dropdown) ===
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.06, 0.05, 0.08)
	popup_style.border_color = border_color
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(4)
	popup_style.set_content_margin_all(4)

	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = button_hover
	popup_hover.set_corner_radius_all(2)

	t.set_stylebox("panel", "PopupMenu", popup_style)
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_color("font_color", "PopupMenu", text_normal)
	t.set_color("font_hover_color", "PopupMenu", gold)

	return t
