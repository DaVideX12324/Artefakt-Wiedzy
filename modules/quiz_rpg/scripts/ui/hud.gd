extends CanvasLayer

## HUD — wyswietla HP, XP, poziom, punkty, streak.
## Dziala z domyslnym fontem Godota, nie wymaga zewnetrznych zasobow.

@onready var hp_bar      : ProgressBar = $HUDPanel/HBoxContainer/HPBar
@onready var hp_label    : Label       = $HUDPanel/HBoxContainer/HPLabel
@onready var xp_bar      : ProgressBar = $HUDPanel/HBoxContainer/XPBar
@onready var level_label : Label       = $HUDPanel/HBoxContainer/LevelLabel
@onready var points_label: Label       = $HUDPanel/HBoxContainer/PointsLabel
@onready var streak_label: Label       = $HUDPanel/HBoxContainer/StreakLabel
@onready var reward_popup: Label       = $RewardPopup
@onready var fade_overlay: ColorRect   = $FadeOverlay

var _ps: Node  # PlayerStats
var _reward_base_y: float = 80.0


func _ready() -> void:
	_ps = CoreManager.get_singleton("PlayerStats")
	if not _ps:
		push_error("HUD: PlayerStats niedostepny przez CoreManager")
		return

	_ps.hp_changed.connect(_on_hp_changed)
	_ps.xp_changed.connect(_on_xp_changed)
	_ps.level_up.connect(_on_level_up)
	_ps.points_changed.connect(_on_points_changed)
	_ps.reward_earned.connect(_on_reward_earned)

	# Style HP bara (czerwony)
	if hp_bar:
		var hp_style = StyleBoxFlat.new()
		hp_style.bg_color = Color(0.8, 0.2, 0.2)
		hp_style.corner_radius_top_left = 3
		hp_style.corner_radius_top_right = 3
		hp_style.corner_radius_bottom_left = 3
		hp_style.corner_radius_bottom_right = 3
		hp_bar.add_theme_stylebox_override("fill", hp_style)

		var hp_bg = StyleBoxFlat.new()
		hp_bg.bg_color = Color(0.2, 0.15, 0.15)
		hp_bg.corner_radius_top_left = 3
		hp_bg.corner_radius_top_right = 3
		hp_bg.corner_radius_bottom_left = 3
		hp_bg.corner_radius_bottom_right = 3
		hp_bar.add_theme_stylebox_override("background", hp_bg)

	# Style XP bara (niebieski)
	if xp_bar:
		var xp_style = StyleBoxFlat.new()
		xp_style.bg_color = Color(0.2, 0.5, 0.9)
		xp_style.corner_radius_top_left = 3
		xp_style.corner_radius_top_right = 3
		xp_style.corner_radius_bottom_left = 3
		xp_style.corner_radius_bottom_right = 3
		xp_bar.add_theme_stylebox_override("fill", xp_style)

		var xp_bg = StyleBoxFlat.new()
		xp_bg.bg_color = Color(0.15, 0.15, 0.2)
		xp_bg.corner_radius_top_left = 3
		xp_bg.corner_radius_top_right = 3
		xp_bg.corner_radius_bottom_left = 3
		xp_bg.corner_radius_bottom_right = 3
		xp_bar.add_theme_stylebox_override("background", xp_bg)

	# Style panelu HUD
	var hud_panel = get_node_or_null("HUDPanel")
	if hud_panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		panel_style.content_margin_left = 12
		panel_style.content_margin_right = 12
		panel_style.content_margin_top = 6
		panel_style.content_margin_bottom = 6
		hud_panel.add_theme_stylebox_override("panel", panel_style)

	if reward_popup:
		reward_popup.visible = false
		_reward_base_y = reward_popup.position.y

	if fade_overlay:
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_update_all()


func _update_all() -> void:
	if not _ps:
		return
	_on_hp_changed(_ps.hp, _ps.max_hp)
	_on_xp_changed(_ps.xp, _ps.xp_to_next_level())
	if level_label:
		level_label.text = "Lvl %d" % _ps.level
	if points_label:
		points_label.text = "Pkt: %d" % _ps.points
	if streak_label:
		streak_label.text = "x%d" % _ps.streak


func _on_hp_changed(new_hp: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.value = (float(new_hp) / float(max_hp)) * 100.0
	if hp_label:
		hp_label.text = "HP %d/%d" % [new_hp, max_hp]


func _on_xp_changed(new_xp: int, xp_to_next: int) -> void:
	if xp_bar:
		xp_bar.value = (float(new_xp) / float(xp_to_next)) * 100.0


func _on_level_up(new_level: int) -> void:
	if level_label:
		level_label.text = "Lvl %d" % new_level
	_show_reward_popup("LEVEL UP! Lvl %d" % new_level)


func _on_points_changed(new_points: int) -> void:
	if points_label:
		points_label.text = "Pkt: %d" % new_points


func _on_reward_earned(reward_name: String) -> void:
	_show_reward_popup("Nagroda: " + reward_name)


func _show_reward_popup(text: String) -> void:
	if not reward_popup:
		return
	reward_popup.text = text
	reward_popup.visible = true
	reward_popup.modulate.a = 1.0
	reward_popup.position.y = _reward_base_y

	var tween = create_tween()
	tween.tween_property(reward_popup, "position:y", _reward_base_y - 50, 0.5)
	tween.parallel().tween_property(reward_popup, "modulate:a", 0.0, 2.0)
	await tween.finished
	reward_popup.visible = false
	reward_popup.position.y = _reward_base_y


func _process(_delta: float) -> void:
	if streak_label and _ps:
		streak_label.text = "x%d" % _ps.streak
