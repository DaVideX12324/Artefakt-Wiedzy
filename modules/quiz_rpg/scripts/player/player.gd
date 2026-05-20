extends CharacterBody2D

## Gracz — ruch top-down 8-kierunkowy, interakcja.
## Programmer art: rysowany kodem jeśli brak AnimatedSprite2D/sprite frames.

@export var speed: float = 200.0

var facing_direction: Vector2 = Vector2.DOWN
var can_move: bool = true
var nearby_interactables: Array = []
var _use_programmer_art: bool = true
var _gm: Node  # GameManager

# Programmer art
const BODY_COLOR := Color(0.2, 0.6, 1.0)
const OUTLINE_COLOR := Color(0.1, 0.3, 0.6)
const DIRECTION_COLOR := Color(1.0, 1.0, 0.3)
const BODY_SIZE := Vector2(16, 20)

# Bobbing animation
var _bob_time: float = 0.0
var _is_moving: bool = false


func _ready() -> void:
	_gm = CoreManager.get_singleton("GameManager")

	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and sprite is AnimatedSprite2D and sprite.sprite_frames:
		if sprite.sprite_frames.get_animation_names().size() > 0:
			_use_programmer_art = false

	if _use_programmer_art:
		if sprite:
			sprite.visible = false


func _physics_process(delta: float) -> void:
	if not can_move or not (_gm and _gm.is_exploring()):
		velocity = Vector2.ZERO
		_is_moving = false
		if not _use_programmer_art:
			_update_sprite_animation("idle")
		else:
			queue_redraw()
		return

	var input = _get_input()
	velocity = input * speed

	if input != Vector2.ZERO:
		facing_direction = input.normalized()
		_is_moving = true
		_bob_time += delta * 10.0
		if not _use_programmer_art:
			_update_sprite_animation("walk")
	else:
		_is_moving = false
		_bob_time = 0.0
		if not _use_programmer_art:
			_update_sprite_animation("idle")

	if _use_programmer_art:
		queue_redraw()

	move_and_slide()


func _draw() -> void:
	if not _use_programmer_art:
		return

	var bob_offset = sin(_bob_time) * 2.0 if _is_moving else 0.0

	_draw_ellipse(Vector2(0, BODY_SIZE.y * 0.4), Vector2(BODY_SIZE.x * 0.5, 4), Color(0, 0, 0, 0.3))

	var body_rect = Rect2(-BODY_SIZE / 2 + Vector2(0, bob_offset - 8), BODY_SIZE)
	draw_rect(body_rect, BODY_COLOR)
	draw_rect(body_rect, OUTLINE_COLOR, false, 2.0)

	var head_center = Vector2(0, -BODY_SIZE.y * 0.5 + bob_offset - 12)
	draw_circle(head_center, 7.0, BODY_COLOR)
	draw_arc(head_center, 7.0, 0, TAU, 24, OUTLINE_COLOR, 2.0)

	var eye_offset = facing_direction.normalized() * 2.5
	var left_eye = head_center + Vector2(-2.5, -1) + eye_offset
	var right_eye = head_center + Vector2(2.5, -1) + eye_offset
	draw_circle(left_eye, 1.5, Color.WHITE)
	draw_circle(right_eye, 1.5, Color.WHITE)
	draw_circle(left_eye + eye_offset * 0.3, 0.8, Color(0.1, 0.1, 0.2))
	draw_circle(right_eye + eye_offset * 0.3, 0.8, Color(0.1, 0.1, 0.2))

	var dir_start = Vector2(0, bob_offset - 8) + facing_direction.normalized() * 14
	var dir_perp = Vector2(-facing_direction.y, facing_direction.x).normalized() * 4
	var triangle = PackedVector2Array([
		dir_start + facing_direction.normalized() * 6,
		dir_start + dir_perp,
		dir_start - dir_perp,
	])
	draw_colored_polygon(triangle, DIRECTION_COLOR)

	if _is_moving:
		var leg_swing = sin(_bob_time) * 4.0
		var hip = Vector2(0, BODY_SIZE.y * 0.3 + bob_offset - 8)
		draw_line(hip + Vector2(-3, 0), hip + Vector2(-3 + leg_swing, 8), OUTLINE_COLOR, 2.0)
		draw_line(hip + Vector2(3, 0), hip + Vector2(3 - leg_swing, 8), OUTLINE_COLOR, 2.0)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, segments: int = 16) -> void:
	var points = PackedVector2Array()
	for i in range(segments + 1):
		var angle = (float(i) / segments) * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	if points.size() > 2:
		draw_colored_polygon(points, color)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _gm and _gm.is_exploring():
		_try_interact()


func _get_input() -> Vector2:
	var input = Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	return input.normalized()


func _update_sprite_animation(state: String) -> void:
	var sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return
	var dir_name = _direction_name()
	var anim_name = state + "_" + dir_name
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	elif sprite.sprite_frames.has_animation(state):
		sprite.play(state)


func _direction_name() -> String:
	if abs(facing_direction.x) > abs(facing_direction.y):
		return "right" if facing_direction.x > 0 else "left"
	else:
		return "down" if facing_direction.y > 0 else "up"


func _try_interact() -> void:
	if nearby_interactables.is_empty():
		return
	var closest = nearby_interactables[0]
	if closest.has_method("interact"):
		closest.interact(self)


func set_can_move(value: bool) -> void:
	can_move = value
	if not value:
		velocity = Vector2.ZERO
		_is_moving = false


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("interactable"):
		nearby_interactables.append(body)


func _on_interaction_area_body_exited(body: Node2D) -> void:
	nearby_interactables.erase(body)


func _on_interaction_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable"):
		nearby_interactables.append(area)


func _on_interaction_area_area_exited(area: Area2D) -> void:
	nearby_interactables.erase(area)
