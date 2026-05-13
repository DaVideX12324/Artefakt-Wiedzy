extends Node

## Korzeń modułu QuizRPG.
## Rejestruje lokalne singletony w CoreManager i ładuje scenę startową modułu.


func _ready() -> void:
	CoreManager.register_singleton("GameManager",       $GameManager)
	CoreManager.register_singleton("DifficultyManager", $DifficultyManager)
	CoreManager.register_singleton("PlayerStats",       $PlayerStats)


func exit_module() -> void:
	CoreManager.launch_module("")
