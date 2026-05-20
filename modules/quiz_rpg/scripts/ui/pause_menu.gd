extends CanvasLayer

## Menu pauzy — zapis, statystyki, wyjście do menu.

@onready var panel: PanelContainer = $Panel
@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeBtn
@onready var save_btn: Button = $Panel/VBoxContainer/SaveBtn
@onready var stats_btn: Button = $Panel/VBoxContainer/StatsBtn
@onready var menu_btn: Button = $Panel/VBoxContainer/MenuBtn

var _paused: bool = false
var _gm: Node


func _ready() -> void:
	_gm = CoreManager.get_singleton("GameManager")
	panel.visible = false
	resume_btn.pressed.connect(_on_resume)
	save_btn.pressed.connect(_on_save)
	stats_btn.pressed.connect(_on_stats)
	menu_btn.pressed.connect(_on_menu)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _gm and _gm.is_exploring():
		_toggle_pause()


func _toggle_pause() -> void:
	_paused = not _paused
	panel.visible = _paused
	get_tree().paused = _paused
	if not _gm:
		return
	if _paused:
		_gm.change_state(_gm.GameState.PAUSED)
	else:
		_gm.change_state(_gm.GameState.EXPLORING)


func _on_resume() -> void:
	_toggle_pause()


func _on_save() -> void:
	if _gm:
		_gm.save_game()
	save_btn.text = "Zapisano!"
	await get_tree().create_timer(1.0).timeout
	save_btn.text = "Zapisz Grę"


func _on_stats() -> void:
	var stats_scene = preload("res://modules/quiz_rpg/scenes/ui/stats_screen.tscn").instantiate()
	add_child(stats_scene)


func _on_menu() -> void:
	get_tree().paused = false
	if _gm:
		_gm.change_state(_gm.GameState.MENU)
		_gm.transition_to_scene("res://modules/quiz_rpg/scenes/ui/main_menu.tscn")
