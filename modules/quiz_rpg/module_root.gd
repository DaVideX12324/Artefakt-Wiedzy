extends Node

## Korzeń modułu QuizRPG.
## Rejestruje lokalne singletony w CoreManager i ładuje scenę startową modułu.

func _ready() -> void:
	_add_singleton("GameManager",       "res://modules/quiz_rpg/autoloads/game_manager.gd")
	_add_singleton("DifficultyManager", "res://modules/quiz_rpg/autoloads/difficulty_manager.gd")
	_add_singleton("PlayerStats",       "res://modules/quiz_rpg/autoloads/player_stats.gd")

	# Po rejestracji singletionów — załaduj menu modułu
	get_tree().change_scene_to_file("res://modules/quiz_rpg/scenes/ui/main_menu.tscn")


func _add_singleton(singleton_name: String, script_path: String) -> void:
	var node := Node.new()
	node.name = singleton_name
	node.set_script(load(script_path))
	add_child(node)
	CoreManager.register_singleton(singleton_name, node)


func exit_module() -> void:
	CoreManager.unregister_module_singletons()  # jeśli CoreManager to obsługuje
	CoreManager.launch_module("")
