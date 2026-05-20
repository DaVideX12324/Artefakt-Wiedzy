extends CanvasLayer
## Menu glowne ekosystemu Artefakt Wiedzy.
## Launchuje wybrane moduly przez CoreManager.


func _ready() -> void:
	$Center/Panel/Margin/VBox/BtnBitBomber.pressed.connect(_on_launch_bitbomber)
	$Center/Panel/Margin/VBox/BtnQuizRPG.pressed.connect(_on_launch_quiz_rpg)
	$Center/Panel/Margin/VBox/BtnQuit.pressed.connect(_on_quit)

	# Powrot do menu gdy modul zostaje zwolniony
	CoreManager.module_unloaded.connect(_on_module_unloaded)


func _on_launch_bitbomber() -> void:
	_hide_menu()
	CoreManager.launch_module("bitbomber")


func _on_launch_quiz_rpg() -> void:
	_hide_menu()
	CoreManager.launch_module("quiz_rpg")


func _on_quit() -> void:
	get_tree().quit()


func _on_module_unloaded(_module_id: String) -> void:
	_show_menu()


func _hide_menu() -> void:
	visible = false


func _show_menu() -> void:
	visible = true
