extends Node

## GameManager — moduł BitBomber
## Zarządza stanami gry i przejściami między nimi.
## Dostępny przez: CoreManager.get_singleton("GameManager")

var debug_enabled: bool = true

enum GameState {
	MENU,
	PLAYING,
	QUIZ_POWERUP,
	QUIZ_LAST_CHANCE,
	ROUND_END,
	GAME_OVER
}

enum WinCondition {
	FIRST_TO_X,
	MOST_WINS_IN_Y
}

signal state_changed(old_state: GameState, new_state: GameState)

var current_state: GameState = GameState.MENU
var num_human_players: int = 1
var num_bots: int = 1
var rounds_to_win: int = 3
var max_rounds: int = 5
var selected_quiz_id: String = ""
var bot_difficulty: int = 0
var win_condition: WinCondition = WinCondition.FIRST_TO_X
var game_node: Node = null


func change_state(new_state: GameState) -> void:
	var old := current_state
	current_state = new_state
	state_changed.emit(old, new_state)


func is_playing() -> bool:
	return current_state == GameState.PLAYING


func is_in_quiz() -> bool:
	return current_state in [GameState.QUIZ_POWERUP, GameState.QUIZ_LAST_CHANCE]


func total_players() -> int:
	return num_human_players + num_bots


func start_game(human_players: int = 1, bots: int = 1) -> void:
	num_human_players = human_players
	num_bots = bots
	var rm := CoreManager.get_singleton("RoundManager")
	if rm:
		rm.reset_session()
	change_state(GameState.PLAYING)
	if game_node:
		game_node.load_arena()
	else:
		get_tree().change_scene_to_file("res://modules/bitbomber/scenes/maps/arena.tscn")


func go_to_menu() -> void:
	change_state(GameState.MENU)
	get_tree().change_scene_to_file("res://modules/bitbomber/scenes/menus/main_menu.tscn")


func log_debug(message: Variant, category: String = "GENERAL") -> void:
	if OS.is_debug_build():
		print("[BB][%s] %s" % [category.to_upper(), str(message)])
