extends CanvasLayer

@onready var load_game_btn: Button = $Center/Panel/Margin/VBox/BtnLoadGame
@onready var stats_panel: PanelContainer = $StatsPanel

func _ready() -> void:
	if not CoreManager.is_module_active("quiz_rpg"):
		CoreManager.launch_module("quiz_rpg")
		await get_tree().process_frame

	var gm := CoreManager.get_singleton("GameManager")
	load_game_btn.disabled = not FileAccess.file_exists(gm.SAVE_PATH) if gm else true

	$Center/Panel/Margin/VBox/BtnNewGame.pressed.connect(_on_new_game)
	$Center/Panel/Margin/VBox/BtnLoadGame.pressed.connect(_on_load_game)
	$Center/Panel/Margin/VBox/BtnStats.pressed.connect(_on_show_stats)
	$Center/Panel/Margin/VBox/BtnQuit.pressed.connect(_on_quit)
	$StatsPanel/StatsMargin/StatsVBox/BtnCloseStats.pressed.connect(_on_close_stats)


func _on_new_game() -> void:
	var gm := CoreManager.get_singleton("GameManager")
	if gm:
		gm.new_game()


func _on_load_game() -> void:
	var gm := CoreManager.get_singleton("GameManager")
	if not gm:
		return
	if gm.load_game():
		gm.change_state(gm.GameState.EXPLORING)
	else:
		push_warning("Nie udalo sie wczytac gry!")


func _on_show_stats() -> void:
	_populate_stats()
	stats_panel.visible = true


func _on_close_stats() -> void:
	stats_panel.visible = false


func _on_quit() -> void:
	CoreManager.unload_module("quiz_rpg")


func _populate_stats() -> void:
	var stats_label = stats_panel.get_node_or_null("StatsMargin/StatsVBox/StatsLabel")
	if not stats_label:
		return
	var ps := CoreManager.get_singleton("PlayerStats")
	if not ps:
		stats_label.text = "Brak danych gracza."
		return
	stats_label.text = """Statystyki gracza:
Poziom: %d
XP: %d / %d
HP: %d / %d
Punkty: %d
Poprawne: %d
Bledne: %d
Seria: %d
Nagrody: %d
Trafnosc: %.0f%%""" % [
		ps.level,
		ps.xp, ps.xp_to_next_level(),
		ps.hp, ps.max_hp,
		ps.points,
		ps.total_correct,
		ps.total_wrong,
		ps.best_streak,
		ps.rewards.size(),
		QuizManager.get_overall_accuracy() * 100,
	]
