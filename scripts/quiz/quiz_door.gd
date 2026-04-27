extends StaticBody2D

## Drzwi/przejście blokowane quizem.
## Programmer art: rysowane kodem (zamknięte = solidne, otwarte = przeźroczyste).

@export var quiz_id: String = "default"
@export var quiz_category: String = "ogolne"
@export var required_correct: int = 3
@export var total_questions: int = 5
@export var door_name: String = "Zamknięte drzwi"
@export var locked_message: String = "Te drzwi wymagają wiedzy, by je otworzyć..."
@export var unlocked: bool = false
@export var door_color: Color = Color(0.55, 0.35, 0.15)  # Brązowy = drewno
@export var door_width: float = 48.0
@export var door_height: float = 16.0

var _player_nearby: bool = false
var _player_ref: Node2D = null
var _use_programmer_art: bool = true
var _anim_time: float = 0.0
var _hint_alpha: float = 0.0


func _ready() -> void:
	add_to_group("interactable")

	# Sprawdź czy Sprite2D ma teksturę
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite is Sprite2D and sprite.texture:
		_use_programmer_art = false
	else:
		if sprite:
			sprite.visible = false

	# Upewnij się że jest CollisionShape
	var col = get_node_or_null("CollisionShape2D")
	if col and not col.shape:
		var rect = RectangleShape2D.new()
		rect.size = Vector2(door_width, door_height)
		col.shape = rect

	# InteractionHint — ukryj, rysujemy sami
	var hint = get_node_or_null("InteractionHint")
	if hint and _use_programmer_art:
		hint.visible = false

	# Upewnij się że DetectionArea ma shape do wykrywania gracza
	var det_area = get_node_or_null("DetectionArea")
	if det_area:
		var det_col = det_area.get_node_or_null("CollisionShape2D")
		if det_col and not det_col.shape:
			var det_rect = RectangleShape2D.new()
			det_rect.size = Vector2(door_width + 40, door_height + 40)
			det_col.shape = det_rect
		elif not det_col:
			var det_col2 = CollisionShape2D.new()
			var det_rect = RectangleShape2D.new()
			det_rect.size = Vector2(door_width + 40, door_height + 40)
			det_col2.shape = det_rect
			det_area.add_child(det_col2)

		# Podłącz sygnały detekcji
		if not det_area.body_entered.is_connected(_on_body_entered):
			det_area.body_entered.connect(_on_body_entered)
		if not det_area.body_exited.is_connected(_on_body_exited):
			det_area.body_exited.connect(_on_body_exited)

	if unlocked:
		_open_door()


func _process(delta: float) -> void:
	_anim_time += delta
	# Płynna animacja hinta
	var target_alpha = 1.0 if (_player_nearby and not unlocked) else 0.0
	_hint_alpha = move_toward(_hint_alpha, target_alpha, delta * 4.0)

	if _use_programmer_art:
		queue_redraw()


func _draw() -> void:
	if not _use_programmer_art:
		return

	var hw = door_width / 2.0
	var hh = door_height / 2.0

	if unlocked:
		# Otwarte — przeźroczyste z przerywaną linią
		draw_rect(Rect2(-hw, -hh, door_width, door_height), Color(door_color, 0.2))
		# Przerywana ramka
		var dash_len = 4.0
		for x in range(int(-hw), int(hw), int(dash_len * 2)):
			draw_line(Vector2(x, -hh), Vector2(mini(x + dash_len, hw), -hh), Color(0.4, 0.8, 0.3, 0.5), 1.0)
			draw_line(Vector2(x, hh), Vector2(mini(x + dash_len, hw), hh), Color(0.4, 0.8, 0.3, 0.5), 1.0)
		# Strzałka "przejdź"
		draw_string(ThemeDB.fallback_font, Vector2(-6, 4), "▸", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.4, 0.8, 0.3, 0.6))
	else:
		# Zamknięte — solidne drzwi
		draw_rect(Rect2(-hw, -hh, door_width, door_height), door_color)
		draw_rect(Rect2(-hw, -hh, door_width, door_height), Color(0.3, 0.2, 0.1), false, 2.0)

		# Deski (linie pionowe)
		var plank_count = 4
		for i in range(1, plank_count):
			var px = -hw + (door_width / plank_count) * i
			draw_line(Vector2(px, -hh + 1), Vector2(px, hh - 1), Color(0.4, 0.25, 0.1), 1.0)

		# Kłódka
		var lock_glow = sin(_anim_time * 2.0) * 0.15
		var lock_color = Color(0.8, 0.7, 0.2, 0.8 + lock_glow)
		draw_circle(Vector2(0, 0), 4.0, lock_color)
		draw_arc(Vector2(0, -3), 3.0, PI, TAU, 8, lock_color, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-3, 2), "🔒", HORIZONTAL_ALIGNMENT_CENTER, -1, 6, lock_color)

	# Hint "[E]" nad drzwiami
	if _hint_alpha > 0.01:
		var hint_color = Color(1, 1, 1, _hint_alpha)
		var hint_text = "[E] " + door_name
		var text_pos = Vector2(-door_width / 2, -hh - 14)
		draw_string(ThemeDB.fallback_font, text_pos, hint_text, HORIZONTAL_ALIGNMENT_LEFT, int(door_width * 2), 11, hint_color)


func interact(player: Node2D) -> void:
	if unlocked:
		return

	_player_ref = player
	if player.has_method("set_can_move"):
		player.set_can_move(false)

	GameManager.change_state(GameManager.GameState.QUIZ_PUZZLE)

	var puzzle_canvas = preload("res://scenes/quiz/quiz_puzzle_ui.tscn").instantiate()
	var puzzle_ui = puzzle_canvas.get_node("Root")
	puzzle_ui.setup(self, player, quiz_id, quiz_category, total_questions, required_correct)
	puzzle_ui.puzzle_finished.connect(_on_puzzle_finished)
	get_tree().current_scene.add_child(puzzle_canvas)


func _on_puzzle_finished(success: bool) -> void:
	if _player_ref and _player_ref.has_method("set_can_move"):
		_player_ref.set_can_move(true)

	GameManager.change_state(GameManager.GameState.EXPLORING)

	if success:
		unlocked = true
		_open_door()


func _open_door() -> void:
	# Wyłącz kolizję
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

	if not _use_programmer_art:
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 0.3, 0.5)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not unlocked:
		_player_nearby = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
