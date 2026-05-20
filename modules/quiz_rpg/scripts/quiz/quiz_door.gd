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
@export var door_color: Color = Color(0.55, 0.35, 0.15)
@export var door_width: float = 48.0
@export var door_height: float = 16.0

var _player_nearby: bool = false
var _player_ref: Node2D = null
var _use_programmer_art: bool = true
var _anim_time: float = 0.0
var _hint_alpha: float = 0.0
var _gm: Node  # GameManager

const PUZZLE_UI_SCENE = "res://modules/quiz_rpg/scenes/quiz/quiz_puzzle_ui.tscn"


func _ready() -> void:
	_gm = CoreManager.get_singleton("GameManager")
	add_to_group("interactable")

	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite is Sprite2D and sprite.texture:
		_use_programmer_art = false
	else:
		if sprite:
			sprite.visible = false

	var col = get_node_or_null("CollisionShape2D")
	if col and not col.shape:
		var rect = RectangleShape2D.new()
		rect.size = Vector2(door_width, door_height)
		col.shape = rect

	var hint = get_node_or_null("InteractionHint")
	if hint and _use_programmer_art:
		hint.visible = false

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

		if not det_area.body_entered.is_connected(_on_body_entered):
			det_area.body_entered.connect(_on_body_entered)
		if not det_area.body_exited.is_connected(_on_body_exited):
			det_area.body_exited.connect(_on_body_exited)

	if unlocked:
		_open_door()


func _process(delta: float) -> void:
	_anim_time += delta
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
		draw_rect(Rect2(-hw, -hh, door_width, door_height), Color(door_color, 0.2))
		var dash_len = 4.0
		for x in range(int(-hw), int(hw), int(dash_len * 2)):
			draw_line(Vector2(x, -hh), Vector2(mini(x + dash_len, hw), -hh), Color(0.4, 0.8, 0.3, 0.5), 1.0)
			draw_line(Vector2(x, hh), Vector2(mini(x + dash_len, hw), hh), Color(0.4, 0.8, 0.3, 0.5), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-6, 4), "▸", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.4, 0.8, 0.3, 0.6))
	else:
		draw_rect(Rect2(-hw, -hh, door_width, door_height), door_color)
		draw_rect(Rect2(-hw, -hh, door_width, door_height), Color(0.3, 0.2, 0.1), false, 2.0)
		var plank_count = 4
		for i in range(1, plank_count):
			var px = -hw + (door_width / plank_count) * i
			draw_line(Vector2(px, -hh + 1), Vector2(px, hh - 1), Color(0.4, 0.25, 0.1), 1.0)
		var lock_glow = sin(_anim_time * 2.0) * 0.15
		var lock_color = Color(0.8, 0.7, 0.2, 0.8 + lock_glow)
		draw_circle(Vector2(0, 0), 4.0, lock_color)
		draw_arc(Vector2(0, -3), 3.0, PI, TAU, 8, lock_color, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-3, 2), "🔒", HORIZONTAL_ALIGNMENT_CENTER, -1, 6, lock_color)

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

	if _gm:
		_gm.change_state(_gm.GameState.QUIZ_PUZZLE)

	if not ResourceLoader.exists(PUZZLE_UI_SCENE):
		push_error("quiz_door: Brak sceny: " + PUZZLE_UI_SCENE)
		if _player_ref and _player_ref.has_method("set_can_move"):
			_player_ref.set_can_move(true)
		return

	var puzzle_canvas = load(PUZZLE_UI_SCENE).instantiate()
	var puzzle_ui = puzzle_canvas.get_node("Root")
	puzzle_ui.setup(self, player, quiz_id, quiz_category, total_questions, required_correct)
	puzzle_ui.puzzle_finished.connect(_on_puzzle_finished)
	get_tree().current_scene.add_child(puzzle_canvas)


func _on_puzzle_finished(success: bool) -> void:
	if _player_ref and _player_ref.has_method("set_can_move"):
		_player_ref.set_can_move(true)

	if _gm:
		_gm.change_state(_gm.GameState.EXPLORING)

	if success:
		unlocked = true
		_open_door()


func _open_door() -> void:
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
