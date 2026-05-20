extends Control

## Menu główne — nowa gra, wczytaj, statystyki, wyjście.
## Stylowane z kodu, nie wymaga Theme resource.

@onready var new_game_btn: Button = $VBoxContainer/NewGameBtn
@onready var load_game_btn: Button = $VBoxContainer/LoadGameBtn
@onready var stats_btn: Button = $VBoxContainer/StatsBtn
@onready var quit_btn: Button = $VBoxContainer/QuitBtn
@onready var title_label: Label = $TitleLabel
@onready var stats_panel: Panel = $StatsPanel

var _title_time: float = 0.0


func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	load_game_btn.pressed.connect(_on_load_game)
	stats_btn.pressed.connect(_on_stats)
	quit_btn.pressed.connect(_on_quit)

	var gm := CoreManager.get_singleton("GameManager")
	load_game_btn.disabled = not FileAccess.file_exists(gm.SAVE_PATH) if gm else true

	if stats_panel:
		stats_panel.visible = false

	# Stylowanie z kodu
	_style_menu()


func _process(delta: float) -> void:
	_title_time += delta
	if title_label:
		# Delikatne pulsowanie tytułu
		var scale_factor = 1.0 + sin(_title_time * 1.5) * 0.02
		title_label.scale = Vector2(scale_factor, scale_factor)


func _style_menu() -> void:
	# Tło
	var bg = get_node_or_null("Background")
	if bg and bg is ColorRect:
		bg.color = Color(0.06, 0.07, 0.12, 1)

	# Tytuł
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5))
		title_label.pivot_offset = title_label.size / 2.0

	# Przyciski
	for btn in [new_game_btn, load_game_btn, stats_btn, quit_btn]:
		if btn:
			UIThemeSetup.style_button(btn, UIThemeSetup.BG_LIGHT, 8)

	# NewGame ma kolor akcentu
	if new_game_btn:
		UIThemeSetup.style_button(new_game_btn, UIThemeSetup.ACCENT, 8)

	# Stats panel
	if stats_panel:
		var style = StyleBoxFlat.new()
		style.bg_color = UIThemeSetup.BG_DARK
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.border_color = UIThemeSetup.BORDER
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		stats_panel.add_theme_stylebox_override("panel", style)

		var stats_label = stats_panel.get_node_or_null("StatsLabel")
		if stats_label:
			stats_label.add_theme_color_override("font_color", UIThemeSetup.TEXT_PRIMARY)

	# Subtitle
	_add_subtitle()


func _add_subtitle() -> void:
	var sub = Label.new()
	sub.text = "Edukacyjna gra RPG z quizami"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", UIThemeSetup.TEXT_SECONDARY)
	sub.add_theme_font_size_override("font_size", 14)

	# Wstaw pod tytuł
	if title_label:
		sub.position = title_label.position + Vector2(0, 50)
		sub.size = Vector2(title_label.size.x, 30)
		add_child(sub)


func _on_new_game() -> void:
	var gm := CoreManager.get_singleton("GameManager")
	if gm:
		gm.new_game()


func _on_load_game() -> void:
	var gm := CoreManager.get_singleton("GameManager")
	if not gm:
		return
	if gm.load_game():
		gm.change_state(gm.GameState.EXPLORING)
	else:
		push_warning("Nie udało się wczytać gry!")


func _on_stats() -> void:
	if stats_panel:
		stats_panel.visible = not stats_panel.visible
		if stats_panel.visible:
			_populate_stats()


func _populate_stats() -> void:
	var stats_label = stats_panel.get_node_or_null("StatsLabel")
	if not stats_label:
		return
	var ps := CoreManager.get_singleton("PlayerStats")
	if not ps:
		return
	stats_label.text = """Statystyki gracza:
Poziom: %d
XP: %d / %d
HP: %d / %d
Punkty: %d
Poprawne: %d
Bledne: %d
Seria: %d
Nagrody: %d
Trafnosc: %.0f%%""" % [
		ps.level,
		ps.xp, ps.xp_to_next_level(),
		ps.hp, ps.max_hp,
		ps.points,
		ps.total_correct,
		ps.total_wrong,
		ps.best_streak,
		ps.rewards.size(),
		QuizManager.get_overall_accuracy() * 100,
	]


func _on_quit() -> void:
	get_tree().quit()
