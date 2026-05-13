extends Node

## Korzeń modułu BitBomber.
## Rejestruje lokalne singletony w CoreManager i ładuje scenę startową modułu.


func _ready() -> void:
	CoreManager.register_singleton("GameManager",  $GameManager)
	CoreManager.register_singleton("RoundManager", $RoundManager)


func exit_module() -> void:
	CoreManager.launch_module("")  # wróć do menu głównego AW
