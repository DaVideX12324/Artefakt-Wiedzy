extends Control

## Ekran statystyk dostępny z pauzy — monitorowanie postępów.

@onready var stats_text: RichTextLabel = $Panel/MarginContainer/VBoxContainer/StatsText
@onready var rewards_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/RewardsList
@onready var close_btn: Button = $Panel/MarginContainer/VBoxContainer/CloseBtn
@onready var difficulty_text: RichTextLabel = $Panel/MarginContainer/VBoxContainer/DifficultyText


func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	_populate()


func _populate() -> void:
	# Ogólne statystyki
	var accuracy = QuizManager.get_overall_accuracy()
	var total_answered = PlayerStats.total_correct + PlayerStats.total_wrong

	stats_text.text = """[b]Postępy gracza[/b]

[b]Poziom:[/b] %d
[b]XP:[/b] %d / %d
[b]Punkty:[/b] %d
[b]HP:[/b] %d / %d

[b]Quiz — statystyki[/b]
Odpowiedzi ogółem: %d
Poprawne: %d (%.0f%%)
Błędne: %d
Aktualna seria: %d
Najlepsza seria: %d
Bonus RNG: +%.0f%%""" % [
		PlayerStats.level,
		PlayerStats.xp, PlayerStats.xp_to_next_level(),
		PlayerStats.points,
		PlayerStats.hp, PlayerStats.max_hp,
		total_answered,
		PlayerStats.total_correct, accuracy * 100,
		PlayerStats.total_wrong,
		PlayerStats.streak,
		PlayerStats.best_streak,
		PlayerStats.rng_bonus * 100,
	]

	# Trudność per kategoria
	var diff_text = "[b]Adaptacyjna trudność[/b]\n"
	diff_text += "Globalna: %.1f / 5\n" % DifficultyManager.get_global_difficulty()
	# Więcej szczegółów per kategoria moglibyśmy dodać
	if difficulty_text:
		difficulty_text.text = diff_text

	# Nagrody
	if rewards_list:
		for child in rewards_list.get_children():
			child.queue_free()
		if PlayerStats.rewards.is_empty():
			var lbl = Label.new()
			lbl.text = "Brak nagród — graj dalej!"
			rewards_list.add_child(lbl)
		else:
			for r in PlayerStats.rewards:
				var lbl = Label.new()
				lbl.text = "🏆 " + r
				rewards_list.add_child(lbl)


func _on_close() -> void:
	queue_free()
