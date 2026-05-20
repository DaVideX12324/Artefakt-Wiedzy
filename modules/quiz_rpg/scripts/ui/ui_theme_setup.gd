extends Node
class_name UIThemeSetup

## Statyczne metody do stylowania UI z kodu — nie wymaga żadnych zewnętrznych zasobów.
## Wywołaj z _ready() dowolnego UI panelu.

# Paleta kolorów
const BG_DARK := Color(0.08, 0.08, 0.12, 0.95)
const BG_MEDIUM := Color(0.12, 0.12, 0.18, 0.95)
const BG_LIGHT := Color(0.18, 0.18, 0.25, 0.9)
const ACCENT := Color(0.3, 0.6, 1.0)
const ACCENT_HOVER := Color(0.4, 0.7, 1.0)
const ACCENT_PRESSED := Color(0.2, 0.5, 0.9)
const TEXT_PRIMARY := Color(0.95, 0.95, 0.98)
const TEXT_SECONDARY := Color(0.65, 0.65, 0.72)
const SUCCESS := Color(0.3, 0.8, 0.4)
const ERROR := Color(0.9, 0.3, 0.3)
const WARNING := Color(0.9, 0.7, 0.2)
const BORDER := Color(0.25, 0.25, 0.35)


## Styluje PanelContainer na ciemny panel
static func style_panel(panel: PanelContainer, color: Color = BG_DARK, corner: int = 12, border: bool = true) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	if border:
		style.border_color = BORDER
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)


## Styluje Button na akcent
static func style_button(btn: Button, color: Color = ACCENT, corner: int = 8) -> void:
	# Normal
	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = corner
	normal.corner_radius_top_right = corner
	normal.corner_radius_bottom_left = corner
	normal.corner_radius_bottom_right = corner
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	# Hover
	var hover = normal.duplicate()
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed
	var pressed = normal.duplicate()
	pressed.bg_color = color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Disabled
	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.3, 0.3, 0.35, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled)

	# Tekst
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", TEXT_SECONDARY)


## Styluje ProgressBar
static func style_progress_bar(bar: ProgressBar, fill_color: Color, bg_color: Color = Color(0.15, 0.15, 0.2), corner: int = 4) -> void:
	var fill = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = corner
	fill.corner_radius_top_right = corner
	fill.corner_radius_bottom_left = corner
	fill.corner_radius_bottom_right = corner
	bar.add_theme_stylebox_override("fill", fill)

	var bg = StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.corner_radius_top_left = corner
	bg.corner_radius_top_right = corner
	bg.corner_radius_bottom_left = corner
	bg.corner_radius_bottom_right = corner
	bar.add_theme_stylebox_override("background", bg)


## Styluje cały quiz UI (combat lub puzzle)
static func style_quiz_ui(root: Control) -> void:
	# Panel główny
	var panel = root.get_node_or_null("Panel")
	if panel and panel is PanelContainer:
		style_panel(panel, BG_DARK, 16)

	# Przyciski odpowiedzi
	var grid = root.get_node_or_null("Panel/MarginContainer/VBoxContainer/AnswersGrid")
	if grid:
		for child in grid.get_children():
			if child is Button:
				style_button(child, BG_LIGHT, 8)

	# HP bary (jeśli istnieją)
	var enemy_hp = root.get_node_or_null("Panel/MarginContainer/VBoxContainer/StatsRow/EnemyHPBar")
	if enemy_hp:
		style_progress_bar(enemy_hp, ERROR, Color(0.2, 0.15, 0.15))

	var player_hp = root.get_node_or_null("Panel/MarginContainer/VBoxContainer/StatsRow/PlayerHPBar")
	if player_hp:
		style_progress_bar(player_hp, SUCCESS, Color(0.15, 0.2, 0.15))

	# Timer bar
	var timer = root.get_node_or_null("Panel/MarginContainer/VBoxContainer/TimerBar")
	if timer:
		style_progress_bar(timer, WARNING, Color(0.2, 0.18, 0.1), 2)

	# Progress bar (puzzle)
	var progress = root.get_node_or_null("Panel/MarginContainer/VBoxContainer/ProgressBar")
	if progress:
		style_progress_bar(progress, ACCENT, Color(0.15, 0.15, 0.2))

	# Kolory tekstu
	_set_label_colors(root)


static func _set_label_colors(node: Node) -> void:
	if node is Label:
		node.add_theme_color_override("font_color", TEXT_PRIMARY)
	if node is RichTextLabel:
		node.add_theme_color_override("default_color", TEXT_PRIMARY)
	for child in node.get_children():
		_set_label_colors(child)
