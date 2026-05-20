extends Node2D
class_name FloatingText

## Unosząca się etykieta z tekstem (damage numbers, "+15 XP", itp.)
## Czysto kodowana — nie wymaga żadnych zasobów.

var text: String = ""
var color: Color = Color.WHITE
var font_size: int = 14
var _elapsed: float = 0.0
var _lifetime: float = 1.2
var _velocity: Vector2 = Vector2(0, -40)


static func create_at(parent: Node, pos: Vector2, p_text: String, p_color: Color = Color.WHITE, p_size: int = 14) -> void:
	var ft = FloatingText.new()
	ft.global_position = pos
	ft.text = p_text
	ft.color = p_color
	ft.font_size = p_size
	# Dodaj losowy offset X żeby nie nakładały się
	ft._velocity = Vector2(randf_range(-15, 15), -40 - randf() * 20)
	parent.add_child(ft)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return

	global_position += _velocity * delta
	_velocity.y -= 20 * delta  # Lekkie przyspieszenie w górę

	queue_redraw()


func _draw() -> void:
	var alpha = 1.0 - (_elapsed / _lifetime)
	var scale = 1.0 + _elapsed * 0.3
	var draw_color = Color(color, alpha)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(-text.length() * font_size * 0.25, 0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		int(font_size * scale),
		draw_color
	)
