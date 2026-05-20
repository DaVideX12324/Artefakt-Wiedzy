extends CharacterBody2D
class_name EnemyBase

## Bazowa klasa przeciwnika — patroluje, wykrywa gracza, inicjuje walke quizowa.
## Programmer art: rysowany kodem jesli brak sprite frames.

@export var enemy_name: String = "Przeciwnik"
@export var quiz_id: String = "default"
@export var quiz_category: String = "ogolne"
@export var question_count: int = 3
@export var hp: int = 50
@export var max_hp: int = 50
@export var damage_on_wrong: int = 15
@export var xp_reward: int = 50
@export var patrol_speed: float = 80.0
@export var detection_radius: float = 150.0
@export var body_color: Color = Color(0.9, 0.2, 0.2)

enum State { IDLE, PATROL, CHASING, COMBAT, DEFEATED }
var state: State = State.PATROL

var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0
var player_ref: Node2D = null
var defeated: bool = false
var _use_programmer_art: bool = true
var _anim_time: float = 0.0
var _flash_timer: float = 0.0
var _flash_color: Color = Color.WHITE

enum EnemyShape { DIAMOND, CIRCLE, TRIANGLE, SQUARE, HEXAGON }
@export var shape_type: EnemyShape = EnemyShape.DIAMOND

const OUTLINE_COLOR := Color(0.15, 0.1, 0.1)
const EYE_COLOR    := Color(1.0, 0.9, 0.2)

# Singletony
var _ps: Node   # PlayerStats
var _dm: Node   # DifficultyManager
var _gm: Node   # GameManager


func _ready() -> void:
	_ps = CoreManager.get_singleton("PlayerStats")
	_dm = CoreManager.get_singleton("DifficultyManager")
	_gm = CoreManager.get_singleton("GameManager")

	add_to_group("enemies")
	add_to_group("interactable")

	var sprite := get_node_or_null("AnimatedSprite2D")
	if sprite and sprite is AnimatedSprite2D and sprite.sprite_frames:
		if sprite.sprite_frames.get_animation_names().size() > 0:
			_use_programmer_art = false

	if _use_programmer_art:
		if sprite:
			sprite.visible = false

	_setup_detection_area()

	if patrol_points.is_empty():
		var pos := global_position
		patrol_points = [
			pos + Vector2(-60, 0),
			pos + Vector2(60, 0),
			pos + Vector2(0, -60),
			pos + Vector2(0, 60),
		]


func _physics_process(delta: float) -> void:
	_anim_time += delta
	if _flash_timer > 0:
		_flash_timer -= delta

	if defeated or state == State.COMBAT:
		if _use_programmer_art:
			queue_redraw()
		return

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASING:
			_chase(delta)
		State.IDLE:
			pass

	if _use_programmer_art:
		queue_redraw()


func _draw() -> void:
	if not _use_programmer_art:
		return

	var hover := sin(_anim_time * 2.0) * 2.0
	var draw_color := body_color
	if _flash_timer > 0:
		draw_color = _flash_color

	draw_circle(Vector2(0, 14), 8.0, Color(0, 0, 0, 0.25))

	match shape_type:
		EnemyShape.DIAMOND:
			_draw_diamond(Vector2(0, hover - 4), 12, 16, draw_color)
		EnemyShape.CIRCLE:
			draw_circle(Vector2(0, hover - 4), 14.0, draw_color)
			draw_arc(Vector2(0, hover - 4), 14.0, 0, TAU, 24, OUTLINE_COLOR, 2.0)
		EnemyShape.TRIANGLE:
			_draw_triangle(Vector2(0, hover - 4), 16, draw_color)
		EnemyShape.SQUARE:
			var r := Rect2(-11, hover - 15, 22, 22)
			draw_rect(r, draw_color)
			draw_rect(r, OUTLINE_COLOR, false, 2.0)
		EnemyShape.HEXAGON:
			_draw_polygon_shape(Vector2(0, hover - 4), 14, 6, draw_color)

	var eye_y := hover - 7.0
	var look_dir := Vector2.ZERO
	if is_instance_valid(player_ref) and state == State.CHASING:
		look_dir = (player_ref.global_position - global_position).normalized() * 2.0

	draw_circle(Vector2(-4 + look_dir.x, eye_y + look_dir.y), 3.0, Color.WHITE)
	draw_circle(Vector2(4 + look_dir.x, eye_y + look_dir.y), 3.0, Color.WHITE)
	draw_circle(Vector2(-4 + look_dir.x * 1.3, eye_y + look_dir.y * 1.3), 1.5, EYE_COLOR)
	draw_circle(Vector2(4 + look_dir.x * 1.3, eye_y + look_dir.y * 1.3), 1.5, EYE_COLOR)

	if not defeated:
		var bar_y := hover - 22
		var bar_w := 24.0
		var bar_h := 3.0
		var hp_ratio := float(hp) / float(max_hp)
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2))
		var hp_color := Color.GREEN if hp_ratio > 0.5 else (Color.YELLOW if hp_ratio > 0.25 else Color.RED)
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w * hp_ratio, bar_h), hp_color)
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), OUTLINE_COLOR, false, 1.0)

	if state == State.CHASING:
		var ex_y := hover - 28
		draw_string(ThemeDB.fallback_font, Vector2(-3, ex_y), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.RED)


func _draw_diamond(center: Vector2, w: float, h: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, 0),
		center + Vector2(0, h),
		center + Vector2(-w, 0),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), OUTLINE_COLOR, 2.0)


func _draw_triangle(center: Vector2, size: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size, size * 0.7),
		center + Vector2(-size, size * 0.7),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), OUTLINE_COLOR, 2.0)


func _draw_polygon_shape(center: Vector2, radius: float, sides: int, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / sides) * TAU - PI / 2.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, OUTLINE_COLOR, 2.0)


func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	var target := patrol_points[current_patrol_index]
	var direction := (target - global_position).normalized()
	velocity = direction * patrol_speed
	move_and_slide()
	if global_position.distance_to(target) < 10:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()


func _chase(delta: float) -> void:
	if not is_instance_valid(player_ref):
		state = State.PATROL
		return
	var direction := (player_ref.global_position - global_position).normalized()
	velocity = direction * patrol_speed * 1.3
	move_and_slide()
	if global_position.distance_to(player_ref.global_position) < 40:
		start_combat(player_ref)


func _setup_detection_area() -> void:
	var det_area := get_node_or_null("DetectionArea")
	if det_area:
		if det_area.get_child_count() == 0:
			var shape := CircleShape2D.new()
			shape.radius = detection_radius
			var col := CollisionShape2D.new()
			col.shape = shape
			det_area.add_child(col)
		else:
			var col := det_area.get_child(0)
			if col is CollisionShape2D and col.shape is CircleShape2D:
				col.shape.radius = detection_radius


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not defeated:
		player_ref = body
		state = State.CHASING


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null
		state = State.PATROL


func interact(player: Node2D) -> void:
	if not defeated:
		start_combat(player)


func start_combat(player: Node2D) -> void:
	if state == State.COMBAT:
		return

	state = State.COMBAT
	velocity = Vector2.ZERO

	if player.has_method("set_can_move"):
		player.set_can_move(false)

	if _gm:
		_gm.change_state(_gm.GameState.QUIZ_COMBAT)

	var diff_range := Vector2i(1, 3)
	if _dm:
		diff_range = _dm.get_difficulty_range(quiz_category)

	var combat_canvas := preload("res://modules/quiz_rpg/scenes/quiz/quiz_combat_ui.tscn").instantiate()
	var combat_ui := combat_canvas.get_node("Root")
	combat_ui.setup(self, player, quiz_id, diff_range, question_count)
	get_tree().current_scene.add_child(combat_canvas)


func on_combat_finished(player_won: bool, player: Node2D) -> void:
	if player.has_method("set_can_move"):
		player.set_can_move(true)

	if player_won:
		defeated = true
		state = State.DEFEATED
		if _ps:
			_ps.add_xp(xp_reward)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.4).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
		await tween.finished
		queue_free()
	else:
		state = State.IDLE
		await get_tree().create_timer(2.0).timeout
		state = State.PATROL

	if _gm:
		_gm.change_state(_gm.GameState.EXPLORING)


func take_quiz_damage(amount: int) -> void:
	hp -= amount
	hp = maxi(hp, 0)
	_flash_color = Color(1.0, 0.3, 0.3)
	_flash_timer = 0.15
	if _use_programmer_art:
		queue_redraw()
	else:
		var sprite := get_node_or_null("AnimatedSprite2D")
		if sprite:
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color.RED, 0.1)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func is_defeated() -> bool:
	return hp <= 0
