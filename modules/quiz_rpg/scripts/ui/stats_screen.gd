extends Control

## Ekran statystyk dostepny z pauzy — monitorowanie postegow.

@onready var stats_text     : RichTextLabel = $Panel/MarginContainer/VBoxContainer/StatsText
@onready var rewards_list   : VBoxContainer = $Panel/MarginContainer/VBoxContainer/RewardsList
@onready var close_btn      : Button        = $Panel/MarginContainer/VBoxContainer/CloseBtn
@onready var difficulty_text: RichTextLabel = $Panel/MarginContainer/VBoxContainer/DifficultyText

var _ps: Node   # PlayerStats
var _dm: Node   # DifficultyManager


func _ready() -> void:
	_ps = CoreManager.get_singleton("PlayerStats")
	_dm = CoreManager.get_singleton("DifficultyManager")
	if not _ps:
		push_error("StatsScreen: PlayerStats niedostepny przez CoreManager")
	close_btn.pressed.connect(_on_close)
	_populate()


func _populate() -> void:
	if not _ps:
		return

	var accuracy     := QuizManager.get_overall_accuracy()
	var total_answered : int = _ps.total_correct + _ps.total_wrong

	stats_text.text = """[b]Postepy gracza[/b]

[b]Poziom:[/b] %d
[b]XP:[/b] %d / %d
[b]Punkty:[/b] %d
[b]HP:[/b] %d / %d

[b]Quiz \u2014 statystyki[/b]
Odpowiedzi ogolem: %d
Poprawne: %d (%.0f%%)
Bledne: %d
Aktualna seria: %d
Najlepsza seria: %d
Bonus RNG: +%.0f%%""" % [
		_ps.level,
		_ps.xp, _ps.xp_to_next_level(),
		_ps.points,
		_ps.hp, _ps.max_hp,
		total_answered,
		_ps.total_correct, accuracy * 100.0,
		_ps.total_wrong,
		_ps.streak,
		_ps.best_streak,
		_ps.rng_bonus * 100.0,
	]

	# Trudnosc per kategoria
	var diff_text := "[b]Adaptacyjna trudnosc[/b]\n"
	if _dm:
		diff_text += "Globalna: %.1f / 5\n" % _dm.get_global_difficulty()
	else:
		diff_text += "(DifficultyManager niedostepny)\n"
	if difficulty_text:
		difficulty_text.text = diff_text

	# Nagrody
	if rewards_list:
		for child in rewards_list.get_children():
			child.queue_free()
		if _ps.rewards.is_empty():
			var lbl = Label.new()
			lbl.text = "Brak nagrod \u2014 graj dalej!"
			rewards_list.add_child(lbl)
		else:
			for r in _ps.rewards:
				var lbl = Label.new()
				lbl.text = "\U0001F3C6 " + r
				rewards_list.add_child(lbl)


func _on_close() -> void:
	queue_free()
