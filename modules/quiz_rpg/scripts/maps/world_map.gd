extends Node2D

## Mapa świata z programmer art — kodowane tło, ściany, dekoracje.

# Wymiary mapy
const MAP_W := 1200.0
const MAP_H := 900.0
const TILE_SIZE := 32
const WALL_THICKNESS := 16.0

# Kolory
const GRASS_COLOR_1 := Color(0.22, 0.45, 0.18)
const GRASS_COLOR_2 := Color(0.25, 0.50, 0.20)
const PATH_COLOR := Color(0.55, 0.48, 0.35)
const WALL_COLOR := Color(0.35, 0.32, 0.28)
const WALL_TOP_COLOR := Color(0.45, 0.42, 0.38)
const WATER_COLOR := Color(0.2, 0.35, 0.65)
const TREE_TRUNK := Color(0.4, 0.28, 0.15)
const TREE_LEAVES := Color(0.15, 0.5, 0.15)
const TREE_LEAVES_2 := Color(0.2, 0.55, 0.2)
const FLOWER_COLORS: Array[Color] = [
	Color(0.9, 0.3, 0.3), Color(0.9, 0.8, 0.2),
	Color(0.7, 0.3, 0.8), Color(0.3, 0.7, 0.9),
]

# Wygenerowane dekoracje (seed-based, deterministyczne)
var _trees: Array[Vector2] = []
var _flowers: Array[Dictionary] = []
var _rocks: Array[Vector2] = []
var _grass_patches: Array[Dictionary] = []
var _path_points: Array[Vector2] = []


func _ready() -> void:
	# Ustaw seed na stały, żeby mapa wyglądała tak samo zawsze
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	# Generuj dekoracje
	_generate_trees(rng, 25)
	_generate_flowers(rng, 40)
	_generate_rocks(rng, 15)
	_generate_grass_patches(rng, 60)
	_generate_path()

	# Ściany wokół mapy (fizyczne)
	_create_wall_colliders()

	queue_redraw()


func _draw() -> void:
	var half_w = MAP_W / 2.0
	var half_h = MAP_H / 2.0

	# 1. Tło — szachownica trawy
	for x in range(-int(half_w), int(half_w), TILE_SIZE):
		for y in range(-int(half_h), int(half_h), TILE_SIZE):
			var col = GRASS_COLOR_1 if (int(x / TILE_SIZE) + int(y / TILE_SIZE)) % 2 == 0 else GRASS_COLOR_2
			draw_rect(Rect2(x, y, TILE_SIZE, TILE_SIZE), col)

	# 2. Ścieżka
	_draw_path()

	# 3. Trawiaste plamki
	for gp in _grass_patches:
		var pos: Vector2 = gp["pos"]
		var size: float = gp["size"]
		draw_line(pos, pos + Vector2(0, -size), Color(0.3, 0.55, 0.25, 0.6), 1.0)
		draw_line(pos, pos + Vector2(-size * 0.3, -size * 0.8), Color(0.25, 0.5, 0.2, 0.5), 1.0)
		draw_line(pos, pos + Vector2(size * 0.3, -size * 0.8), Color(0.25, 0.5, 0.2, 0.5), 1.0)

	# 4. Kwiaty
	for fl in _flowers:
		var pos: Vector2 = fl["pos"]
		var col: Color = fl["color"]
		draw_circle(pos, 2.5, col)
		draw_circle(pos, 1.0, Color(1, 1, 0.7))
		draw_line(pos, pos + Vector2(0, 4), Color(0.2, 0.5, 0.15), 1.0)

	# 5. Kamienie
	for rk in _rocks:
		draw_circle(rk + Vector2(0, 1), 5, Color(0, 0, 0, 0.15))
		draw_circle(rk, 5, Color(0.5, 0.5, 0.48))
		draw_arc(rk + Vector2(-1, -1), 3, PI * 0.8, PI * 1.5, 6, Color(0.6, 0.6, 0.58), 1.0)

	# 6. Drzewa
	for tr in _trees:
		_draw_tree(tr)

	# 7. Ściany (wizualne)
	_draw_walls(half_w, half_h)

	# 8. Etykiety stref
	draw_string(ThemeDB.fallback_font, Vector2(-half_w + 20, -half_h + 30),
		"~ Kraina Wiedzy ~", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0.8, 0.5))


func _draw_tree(pos: Vector2) -> void:
	# Cień
	draw_ellipse_at(pos + Vector2(0, 12), Vector2(10, 4), Color(0, 0, 0, 0.2))
	# Pień
	draw_rect(Rect2(pos.x - 3, pos.y - 5, 6, 17), TREE_TRUNK)
	# Korona (nakładające się kółka)
	draw_circle(pos + Vector2(0, -14), 11, TREE_LEAVES)
	draw_circle(pos + Vector2(-6, -10), 8, TREE_LEAVES_2)
	draw_circle(pos + Vector2(6, -10), 8, TREE_LEAVES_2)
	draw_circle(pos + Vector2(0, -18), 7, TREE_LEAVES_2)


func draw_ellipse_at(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts = PackedVector2Array()
	for i in range(13):
		var angle = (float(i) / 12) * TAU
		pts.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(pts, color)


func _draw_path() -> void:
	if _path_points.size() < 2:
		return
	for i in range(_path_points.size() - 1):
		draw_line(_path_points[i], _path_points[i + 1], PATH_COLOR, 24.0)
		# Krawędzie ścieżki
		draw_line(_path_points[i], _path_points[i + 1], Color(PATH_COLOR, 0.5), 30.0)


func _draw_walls(half_w: float, half_h: float) -> void:
	# Górna ściana
	draw_rect(Rect2(-half_w, -half_h, MAP_W, WALL_THICKNESS), WALL_COLOR)
	draw_rect(Rect2(-half_w, -half_h, MAP_W, WALL_THICKNESS * 0.6), WALL_TOP_COLOR)
	# Dolna
	draw_rect(Rect2(-half_w, half_h - WALL_THICKNESS, MAP_W, WALL_THICKNESS), WALL_COLOR)
	draw_rect(Rect2(-half_w, half_h - WALL_THICKNESS, MAP_W, WALL_THICKNESS * 0.6), WALL_TOP_COLOR)
	# Lewa
	draw_rect(Rect2(-half_w, -half_h, WALL_THICKNESS, MAP_H), WALL_COLOR)
	draw_rect(Rect2(-half_w, -half_h, WALL_THICKNESS * 0.6, MAP_H), WALL_TOP_COLOR)
	# Prawa
	draw_rect(Rect2(half_w - WALL_THICKNESS, -half_h, WALL_THICKNESS, MAP_H), WALL_COLOR)
	draw_rect(Rect2(half_w - WALL_THICKNESS * 0.4, -half_h, WALL_THICKNESS * 0.6, MAP_H), WALL_TOP_COLOR)

	# Cegły / desenie na ścianach
	for x in range(-int(half_w), int(half_w), 20):
		draw_line(Vector2(x, -half_h), Vector2(x, -half_h + WALL_THICKNESS), Color(0, 0, 0, 0.1), 1.0)
		draw_line(Vector2(x, half_h - WALL_THICKNESS), Vector2(x, half_h), Color(0, 0, 0, 0.1), 1.0)


func _generate_trees(rng: RandomNumberGenerator, count: int) -> void:
	for i in range(count):
		var pos = Vector2(
			rng.randf_range(-MAP_W * 0.4, MAP_W * 0.4),
			rng.randf_range(-MAP_H * 0.4, MAP_H * 0.4)
		)
		# Nie generuj drzew blisko środka (spawn gracza)
		if pos.length() > 80:
			_trees.append(pos)


func _generate_flowers(rng: RandomNumberGenerator, count: int) -> void:
	for i in range(count):
		_flowers.append({
			"pos": Vector2(
				rng.randf_range(-MAP_W * 0.45, MAP_W * 0.45),
				rng.randf_range(-MAP_H * 0.45, MAP_H * 0.45)
			),
			"color": FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()],
		})


func _generate_rocks(rng: RandomNumberGenerator, count: int) -> void:
	for i in range(count):
		_rocks.append(Vector2(
			rng.randf_range(-MAP_W * 0.4, MAP_W * 0.4),
			rng.randf_range(-MAP_H * 0.4, MAP_H * 0.4)
		))


func _generate_grass_patches(rng: RandomNumberGenerator, count: int) -> void:
	for i in range(count):
		_grass_patches.append({
			"pos": Vector2(
				rng.randf_range(-MAP_W * 0.45, MAP_W * 0.45),
				rng.randf_range(-MAP_H * 0.45, MAP_H * 0.45)
			),
			"size": rng.randf_range(4.0, 8.0),
		})


func _generate_path() -> void:
	# Ścieżka od spawnu do kluczowych punktów
	_path_points = [
		Vector2(0, 100),
		Vector2(0, 0),       # Spawn
		Vector2(0, -100),
		Vector2(0, -200),    # Do bramy 1
	]


func _create_wall_colliders() -> void:
	var half_w = MAP_W / 2.0
	var half_h = MAP_H / 2.0

	_add_wall_body(Vector2(0, -half_h + WALL_THICKNESS / 2), Vector2(MAP_W, WALL_THICKNESS))
	_add_wall_body(Vector2(0, half_h - WALL_THICKNESS / 2), Vector2(MAP_W, WALL_THICKNESS))
	_add_wall_body(Vector2(-half_w + WALL_THICKNESS / 2, 0), Vector2(WALL_THICKNESS, MAP_H))
	_add_wall_body(Vector2(half_w - WALL_THICKNESS / 2, 0), Vector2(WALL_THICKNESS, MAP_H))


func _add_wall_body(pos: Vector2, size: Vector2) -> void:
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 4  # Walls
	body.collision_mask = 0

	var shape = RectangleShape2D.new()
	shape.size = size
	var col = CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)

	add_child(body)
