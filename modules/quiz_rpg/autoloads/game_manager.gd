extends Node

## GameManager — moduł QuizRPG
## Zarządza stanami gry RPG, scenami i zapisem.
## Dostępny przez: CoreManager.get_singleton("GameManager")

enum GameState { MENU, EXPLORING, QUIZ_COMBAT, QUIZ_PUZZLE, PAUSED, CUTSCENE }

signal state_changed(old_state: GameState, new_state: GameState)
signal scene_transition_started
signal scene_transition_finished

var current_state: GameState = GameState.MENU
var current_map_path: String = ""
var _transition_in_progress: bool = false


func change_state(new_state: GameState) -> void:
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


func is_exploring() -> bool:
	return current_state == GameState.EXPLORING


func is_in_quiz() -> bool:
	return current_state in [GameState.QUIZ_COMBAT, GameState.QUIZ_PUZZLE]


func transition_to_scene(scene_path: String) -> void:
	if _transition_in_progress:
		return
	_transition_in_progress = true
	scene_transition_started.emit()
	var tree = get_tree()
	var tween = create_tween()
	tween.tween_method(_set_fade, 0.0, 1.0, 0.3)
	await tween.finished
	tree.change_scene_to_file(scene_path)
	current_map_path = scene_path
	await tree.tree_changed
	tween = create_tween()
	tween.tween_method(_set_fade, 1.0, 0.0, 0.3)
	await tween.finished
	_transition_in_progress = false
	scene_transition_finished.emit()


func _set_fade(value: float) -> void:
	var fade_rect = get_node_or_null("/root/HUD/FadeOverlay")
	if fade_rect:
		fade_rect.modulate.a = value


const SAVE_PATH = "user://savegame_rpg.json"

func save_game() -> void:
	var ps  := CoreManager.get_singleton("PlayerStats")
	var dm  := CoreManager.get_singleton("DifficultyManager")
	var save_data = {
		"player_stats": ps.get_save_data()  if ps else {},
		"quiz_progress": QuizManager.get_save_data(),
		"difficulty": dm.get_save_data()    if dm else {},
		"current_map": current_map_path,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return false
	file.close()
	var data = json.data
	var ps := CoreManager.get_singleton("PlayerStats")
	var dm := CoreManager.get_singleton("DifficultyManager")
	if ps: ps.load_save_data(data.get("player_stats", {}))
	QuizManager.load_save_data(data.get("quiz_progress", {}))
	if dm: dm.load_save_data(data.get("difficulty", {}))
	if data.has("current_map") and data["current_map"] != "":
		transition_to_scene(data["current_map"])
	return true


func new_game() -> void:
	var ps := CoreManager.get_singleton("PlayerStats")
	var dm := CoreManager.get_singleton("DifficultyManager")
	if ps: ps.reset()
	QuizManager.reset()
	if dm: dm.reset()
	change_state(GameState.EXPLORING)
	transition_to_scene("res://modules/quiz_rpg/scenes/maps/world_map.tscn")


func log_debug(message: Variant, category: String = "GENERAL") -> void:
	if OS.is_debug_build():
		print("[RPG][%s] %s" % [category.to_upper(), str(message)])
