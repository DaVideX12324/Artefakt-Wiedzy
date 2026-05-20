extends Node2D
class_name HitParticles

## Efekt cząsteczek hit/damage — kodowany, nie wymaga żadnych assetów.
## Użycie: var fx = HitParticles.new(); fx.spawn(global_position, color); add_child(fx)

var particles: Array[Dictionary] = []
var _lifetime: float = 0.8
var _elapsed: float = 0.0


static func create_at(parent: Node, pos: Vector2, color: Color = Color.RED, count: int = 8) -> void:
	var fx = HitParticles.new()
	fx.global_position = pos
	fx._spawn_particles(count, color)
	parent.add_child(fx)


func _spawn_particles(count: int, color: Color) -> void:
	for i in range(count):
		var angle = randf() * TAU
		var speed = randf_range(40.0, 120.0)
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"size": randf_range(2.0, 5.0),
			"color": color.lightened(randf() * 0.3),
			"life": 1.0,
		})


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return

	for p in particles:
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.95  # Spowolnienie
		p["vel"].y += 100 * delta  # Grawitacja
		p["life"] -= delta / _lifetime
		p["size"] *= 0.98

	queue_redraw()


func _draw() -> void:
	for p in particles:
		if p["life"] > 0:
			var col = Color(p["color"], p["life"])
			draw_circle(p["pos"], p["size"], col)
