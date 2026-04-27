extends Control

## Turn-based combat controller.
##
## Flow tury gracza:
##   1. Gracz wybiera akcję: ATAK / OBRONA / LECZENIE / UCIECZKA
##   2. Pojawia się pytanie quizowe
##   3. Wynik quizu modyfikuje akcję:
##
##   ATAK + poprawna   → pełne obrażenia (+ szansa na krytyk z RNG bonus)
##   ATAK + błędna     → miss / dodge / block przez wroga (losowo)
##
##   OBRONA + poprawna → pełny blok (0 dmg w turze wroga)
##   OBRONA + błędna   → częściowy blok (50% dmg w turze wroga)
##
##   LECZENIE + poprawna → pełne leczenie (30% max HP)
##   LECZENIE + błędna   → małe leczenie (10% max HP)
##
##   4. Tura wroga — wróg atakuje (modyfikowane przez obronę gracza)
##   5. Sprawdź koniec walki → powtórz

signal combat_finished(player_won: bool)

# === Stany walki ===
enum Phase { ACTION_SELECT, QUIZ, PLAYER_RESULT, ENEMY_TURN, COMBAT_END }
enum Action { ATTACK, DEFEND, HEAL, FLEE }

var phase: Phase = Phase.ACTION_SELECT
var chosen_action: Action = Action.ATTACK
var quiz_correct: bool = false
var defending: bool = false  # Czy gracz bronił się w tej turze

# === Referencje ===
var enemy: Node2D  # EnemyBase
var player: Node2D
var quiz_id: String
var _diff_range: Vector2i
var _question_count: int

# === Staty walki ===
var enemy_hp: int = 50
var enemy_max_hp: int = 50
var enemy_name_str: String = "Przeciwnik"
var enemy_base_damage: int = 15
var player_base_damage: int = 20
var turn_number: int = 0

# === Node referencje (ustawiane w _ready) ===
var action_panel: VBoxContainer
var quiz_panel: VBoxContainer
var result_label: Label
var question_label: RichTextLabel
var answer_buttons: Array[Button] = []
var enemy_hp_bar: ProgressBar
var player_hp_bar: ProgressBar
var enemy_name_label: Label
var player_name_label: Label
var enemy_sprite_node: Control
var player_sprite_node: Control
var turn_label: Label
var streak_label: Label
var combat_log: RichTextLabel

# Przyciski akcji
var atk_btn: Button
var def_btn: Button
var heal_btn: Button
var flee_btn: Button

# Timer quizu
var timer_bar: ProgressBar
var _timer: float = 0.0
var _time_limit: float = 20.0
var _timer_active: bool = false
var _answering: bool = false


## Wywoływane PRZED dodaniem do drzewa
func setup(p_enemy: Node2D, p_player: Node2D, p_quiz_id: String,
		diff_range: Vector2i, question_count: int) -> void:
	enemy = p_enemy
	player = p_player
	quiz_id = p_quiz_id
	_diff_range = diff_range
	_question_count = question_count

	# Kopiuj staty wroga
	enemy_hp = p_enemy.hp
	enemy_max_hp = p_enemy.max_hp
	enemy_name_str = p_enemy.enemy_name
	enemy_base_damage = p_enemy.damage_on_wrong
	player_base_damage = 20


## Wywoływane PO dodaniu do drzewa
func _ready() -> void:
	# --- Pobierz referencje ---
	action_panel = $Panel/HSplit/RightSide/ActionPanel
	quiz_panel = $Panel/HSplit/RightSide/QuizPanel
	result_label = $Panel/HSplit/RightSide/ResultLabel

	question_label = $Panel/HSplit/RightSide/QuizPanel/QuestionLabel
	answer_buttons = [
		$Panel/HSplit/RightSide/QuizPanel/AnswersGrid/Btn0,
		$Panel/HSplit/RightSide/QuizPanel/AnswersGrid/Btn1,
		$Panel/HSplit/RightSide/QuizPanel/AnswersGrid/Btn2,
		$Panel/HSplit/RightSide/QuizPanel/AnswersGrid/Btn3,
	]
	timer_bar = $Panel/HSplit/RightSide/QuizPanel/TimerBar

	enemy_hp_bar = $Panel/HSplit/LeftSide/Arena/EnemySection/EnemyHPBar
	player_hp_bar = $Panel/HSplit/LeftSide/Arena/PlayerSection/PlayerHPBar
	enemy_name_label = $Panel/HSplit/LeftSide/Arena/EnemySection/EnemyName
	player_name_label = $Panel/HSplit/LeftSide/Arena/PlayerSection/PlayerName
	enemy_sprite_node = $Panel/HSplit/LeftSide/Arena/EnemySection/EnemySprite
	player_sprite_node = $Panel/HSplit/LeftSide/Arena/PlayerSection/PlayerSprite
	turn_label = $Panel/HSplit/LeftSide/TurnLabel
	streak_label = $Panel/HSplit/LeftSide/StreakLabel
	combat_log = $Panel/HSplit/LeftSide/CombatLog

	atk_btn = $Panel/HSplit/RightSide/ActionPanel/AtkBtn
	def_btn = $Panel/HSplit/RightSide/ActionPanel/DefBtn
	heal_btn = $Panel/HSplit/RightSide/ActionPanel/HealBtn
	flee_btn = $Panel/HSplit/RightSide/ActionPanel/FleeBtn

	# --- Podłącz sygnały ---
	atk_btn.pressed.connect(_on_action.bind(Action.ATTACK))
	def_btn.pressed.connect(_on_action.bind(Action.DEFEND))
	heal_btn.pressed.connect(_on_action.bind(Action.HEAL))
	flee_btn.pressed.connect(_on_action.bind(Action.FLEE))

	for i in range(answer_buttons.size()):
		answer_buttons[i].pressed.connect(_on_answer.bind(i))

	# --- Styluj ---
	UIThemeSetup.style_quiz_ui(self)
	_style_action_buttons()
	_style_arena()

	# --- Inicjalizuj ---
	enemy_name_label.text = enemy_name_str
	player_name_label.text = PlayerStats.player_name
	_update_hp_bars()
	_log("Walka z %s rozpoczeta!" % enemy_name_str)
	_start_player_turn()


func _process(delta: float) -> void:
	if _timer_active:
		_timer -= delta
		if timer_bar:
			timer_bar.value = maxf((_timer / _time_limit) * 100.0, 0.0)
		if _timer <= 0:
			_timer_active = false
			_on_time_expired()


# =============================================================
#  FLOW TURY
# =============================================================

func _start_player_turn() -> void:
	turn_number += 1
	defending = false
	phase = Phase.ACTION_SELECT

	turn_label.text = "Tura %d — Twoj ruch" % turn_number
	streak_label.text = "Seria: %d  |  RNG: +%.0f%%" % [PlayerStats.streak, PlayerStats.rng_bonus * 100]

	action_panel.visible = true
	quiz_panel.visible = false
	result_label.visible = false
	_set_action_buttons_enabled(true)


func _on_action(action: Action) -> void:
	if phase != Phase.ACTION_SELECT:
		return

	chosen_action = action

	if action == Action.FLEE:
		_try_flee()
		return

	# Rozpocznij quiz
	_set_action_buttons_enabled(false)
	phase = Phase.QUIZ

	var q = QuizManager.start_quiz(quiz_id, _diff_range, 1)
	if q.is_empty():
		# Brak pytań — traktuj jako poprawna
		_resolve_action(true)
		return

	action_panel.visible = false
	quiz_panel.visible = true
	_show_question(q)


func _show_question(q: Dictionary) -> void:
	_answering = true
	_timer = _time_limit
	_timer_active = true

	question_label.text = q.get("question", "???")
	var answers: Array = q.get("answers", [])
	for i in range(4):
		if i < answers.size():
			answer_buttons[i].text = answers[i]
			answer_buttons[i].visible = true
			answer_buttons[i].disabled = false
			answer_buttons[i].remove_theme_color_override("font_color")
		else:
			answer_buttons[i].visible = false


func _on_answer(index: int) -> void:
	if not _answering:
		return
	_answering = false
	_timer_active = false

	var result = QuizManager.answer_current(index)
	var correct = result.get("correct", false)
	var correct_idx = result.get("correct_index", 0)
	var category = quiz_id

	# Pokaż poprawną
	for i in range(4):
		answer_buttons[i].disabled = true
	answer_buttons[correct_idx].add_theme_color_override("font_color", Color.GREEN)
	if not correct and index >= 0 and index < answer_buttons.size():
		answer_buttons[index].add_theme_color_override("font_color", Color.RED)

	# Statystyki
	if correct:
		PlayerStats.on_correct_answer()
		DifficultyManager.record_answer(category, true)
	else:
		PlayerStats.on_wrong_answer()
		DifficultyManager.record_answer(category, false)

	await get_tree().create_timer(0.8).timeout
	_resolve_action(correct)


func _on_time_expired() -> void:
	if not _answering:
		return
	_answering = false
	QuizManager.answer_current(-1)
	PlayerStats.on_wrong_answer()

	for btn in answer_buttons:
		btn.disabled = true

	_log("Czas minal!")
	await get_tree().create_timer(0.6).timeout
	_resolve_action(false)


# =============================================================
#  ROZWIĄZANIE AKCJI
# =============================================================

func _resolve_action(correct: bool) -> void:
	quiz_correct = correct
	phase = Phase.PLAYER_RESULT
	quiz_panel.visible = false
	result_label.visible = true

	match chosen_action:
		Action.ATTACK:
			_resolve_attack(correct)
		Action.DEFEND:
			_resolve_defend(correct)
		Action.HEAL:
			_resolve_heal(correct)

	_update_hp_bars()
	streak_label.text = "Seria: %d  |  RNG: +%.0f%%" % [PlayerStats.streak, PlayerStats.rng_bonus * 100]

	await get_tree().create_timer(1.5).timeout

	# Sprawdź czy wróg pokonany
	if enemy_hp <= 0:
		_end_combat(true)
		return

	# Tura wroga
	_enemy_turn()


func _resolve_attack(correct: bool) -> void:
	if correct:
		var dmg = player_base_damage
		var crit = false

		# Szansa na krytyk z RNG bonus
		if PlayerStats.roll_with_bonus(0.15):
			dmg = int(dmg * 1.8)
			crit = true

		enemy_hp = maxi(enemy_hp - dmg, 0)
		_flash_sprite(enemy_sprite_node, Color.RED)

		if crit:
			result_label.text = "TRAFIENIE KRYTYCZNE! -%d DMG" % dmg
			result_label.add_theme_color_override("font_color", Color.GOLD)
			_log("Atak krytyczny! %s otrzymuje %d obrazen!" % [enemy_name_str, dmg])
			FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), "KRYT -%d" % dmg, Color.GOLD, 16)
		else:
			result_label.text = "Trafienie! -%d DMG" % dmg
			result_label.add_theme_color_override("font_color", Color.GREEN)
			_log("Atak trafia! %s otrzymuje %d obrazen." % [enemy_name_str, dmg])
			FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), "-%d" % dmg, Color.YELLOW, 14)

		HitParticles.create_at(enemy, enemy.global_position, Color(1.0, 0.5, 0.2))
	else:
		# Miss / Dodge / Block
		var fail_type = ["Pudlo!", "Unik wroga!", "Blok wroga!"][randi() % 3]
		result_label.text = fail_type
		result_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_log(fail_type + " Atak nie trafil.")
		_dodge_anim(enemy_sprite_node)
		FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), fail_type, Color(0.8, 0.8, 0.8), 12)


func _resolve_defend(correct: bool) -> void:
	defending = true
	if correct:
		result_label.text = "Pelna obrona! Nastepny atak zablokowany."
		result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		_log("Przyjmujesz pozycje obronna — pelny blok!")
		_flash_sprite(player_sprite_node, Color(0.3, 0.7, 1.0))
	else:
		result_label.text = "Czesciowa obrona. Nastepny atak -50%."
		result_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
		_log("Obrona czesciowa — zredukujesz 50% obrazen.")


func _resolve_heal(correct: bool) -> void:
	var heal_pct = 0.30 if correct else 0.10
	var heal_amount = int(PlayerStats.max_hp * heal_pct)
	PlayerStats.heal(heal_amount)
	_flash_sprite(player_sprite_node, Color.GREEN)

	if correct:
		result_label.text = "Pelne leczenie! +%d HP" % heal_amount
		result_label.add_theme_color_override("font_color", Color.GREEN)
		_log("Leczenie udane! Odzyskujesz %d HP." % heal_amount)
	else:
		result_label.text = "Slabe leczenie... +%d HP" % heal_amount
		result_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
		_log("Leczenie czesciowe. Odzyskujesz %d HP." % heal_amount)

	FloatingText.create_at(player, player.global_position + Vector2(0, -20), "+%d HP" % heal_amount, Color.GREEN, 14)


func _try_flee() -> void:
	# 30% bazowa szansa + RNG bonus
	if PlayerStats.roll_with_bonus(0.30):
		_log("Ucieczka udana!")
		result_label.visible = true
		result_label.text = "Uciekasz!"
		result_label.add_theme_color_override("font_color", Color.WHITE)
		await get_tree().create_timer(1.0).timeout
		_end_combat(false, true)  # fled = true
	else:
		_log("Ucieczka nieudana! Tracisz ture.")
		result_label.visible = true
		result_label.text = "Nie udalo sie uciec!"
		result_label.add_theme_color_override("font_color", Color.RED)
		action_panel.visible = false
		await get_tree().create_timer(1.0).timeout
		_enemy_turn()


# =============================================================
#  TURA WROGA
# =============================================================

func _enemy_turn() -> void:
	if enemy_hp <= 0:
		_end_combat(true)
		return

	phase = Phase.ENEMY_TURN
	turn_label.text = "Tura %d — %s atakuje!" % [turn_number, enemy_name_str]
	result_label.visible = true

	await get_tree().create_timer(0.5).timeout

	# Wróg zawsze atakuje (proste AI)
	var raw_damage = enemy_base_damage + randi() % 8  # Losowy rozrzut

	var actual_damage: int
	if defending and quiz_correct:
		# Pełny blok
		actual_damage = 0
		result_label.text = "BLOK! %s atakuje ale nie zadaje obrazen!" % enemy_name_str
		result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		_log("%s atakuje — PELNY BLOK! 0 obrazen." % enemy_name_str)
		_flash_sprite(player_sprite_node, Color(0.3, 0.7, 1.0))
		FloatingText.create_at(player, player.global_position + Vector2(0, -20), "BLOK!", Color(0.3, 0.7, 1.0), 14)
	elif defending and not quiz_correct:
		# Częściowy blok — 50%
		actual_damage = int(raw_damage * 0.5)
		PlayerStats.take_damage(actual_damage)
		result_label.text = "Czesciowy blok! %s zadaje %d DMG (-%d zblokowane)" % [enemy_name_str, actual_damage, raw_damage - actual_damage]
		result_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		_log("%s atakuje — czesciowy blok. %d obrazen (z %d)." % [enemy_name_str, actual_damage, raw_damage])
		_flash_sprite(player_sprite_node, Color(0.8, 0.6, 0.3))
		FloatingText.create_at(player, player.global_position + Vector2(0, -20), "-%d (blok)" % actual_damage, Color.ORANGE, 12)
	else:
		# Brak obrony — pełne obrażenia
		actual_damage = raw_damage
		PlayerStats.take_damage(actual_damage)
		result_label.text = "%s atakuje! -%d HP" % [enemy_name_str, actual_damage]
		result_label.add_theme_color_override("font_color", Color.RED)
		_log("%s atakuje! Otrzymujesz %d obrazen." % [enemy_name_str, actual_damage])
		_flash_sprite(player_sprite_node, Color.RED)
		HitParticles.create_at(player, player.global_position, Color.RED, 6)
		FloatingText.create_at(player, player.global_position + Vector2(0, -20), "-%d" % actual_damage, Color.RED, 14)

	_update_hp_bars()

	await get_tree().create_timer(1.5).timeout

	# Sprawdź czy gracz żyje
	if not PlayerStats.is_alive():
		_end_combat(false)
		return

	# Następna tura gracza
	_start_player_turn()


# =============================================================
#  KONIEC WALKI
# =============================================================

func _end_combat(player_won: bool, fled: bool = false) -> void:
	phase = Phase.COMBAT_END
	action_panel.visible = false
	quiz_panel.visible = false
	result_label.visible = true

	if player_won:
		result_label.text = "ZWYCIESTWO! +%d XP" % enemy.xp_reward
		result_label.add_theme_color_override("font_color", Color.GOLD)
		_log("Zwyciezyles! Zdobywasz %d XP." % enemy.xp_reward)
	elif fled:
		result_label.text = "Udana ucieczka."
		result_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		result_label.text = "Porazka..."
		result_label.add_theme_color_override("font_color", Color.RED)
		_log("Porazka...")

	await get_tree().create_timer(2.0).timeout

	# Synchronizuj HP wroga
	enemy.hp = enemy_hp

	combat_finished.emit(player_won)
	enemy.on_combat_finished(player_won, player)
	get_parent().queue_free()


# =============================================================
#  UI HELPERS
# =============================================================

func _update_hp_bars() -> void:
	if enemy_hp_bar:
		enemy_hp_bar.value = (float(enemy_hp) / float(enemy_max_hp)) * 100.0
	if player_hp_bar:
		player_hp_bar.value = (float(PlayerStats.hp) / float(PlayerStats.max_hp)) * 100.0


func _log(text: String) -> void:
	if combat_log:
		combat_log.append_text(text + "\n")
		# Auto-scroll
		combat_log.scroll_to_line(combat_log.get_line_count() - 1)


func _flash_sprite(sprite_control: Control, color: Color) -> void:
	if not sprite_control:
		return
	var tween = create_tween()
	tween.tween_property(sprite_control, "modulate", color, 0.1)
	tween.tween_property(sprite_control, "modulate", Color.WHITE, 0.2)


func _dodge_anim(sprite_control: Control) -> void:
	if not sprite_control:
		return
	var orig_pos = sprite_control.position
	var tween = create_tween()
	tween.tween_property(sprite_control, "position:x", orig_pos.x + 20, 0.1)
	tween.tween_property(sprite_control, "position:x", orig_pos.x, 0.15)


func _set_action_buttons_enabled(enabled: bool) -> void:
	atk_btn.disabled = not enabled
	def_btn.disabled = not enabled
	heal_btn.disabled = not enabled
	flee_btn.disabled = not enabled


func _style_action_buttons() -> void:
	UIThemeSetup.style_button(atk_btn, Color(0.8, 0.25, 0.2), 6)
	UIThemeSetup.style_button(def_btn, Color(0.2, 0.45, 0.8), 6)
	UIThemeSetup.style_button(heal_btn, Color(0.2, 0.7, 0.3), 6)
	UIThemeSetup.style_button(flee_btn, UIThemeSetup.BG_LIGHT, 6)


func _style_arena() -> void:
	# HP bary
	if enemy_hp_bar:
		UIThemeSetup.style_progress_bar(enemy_hp_bar, Color(0.8, 0.2, 0.2), Color(0.25, 0.12, 0.12))
	if player_hp_bar:
		UIThemeSetup.style_progress_bar(player_hp_bar, Color(0.2, 0.7, 0.3), Color(0.12, 0.2, 0.12))
	if timer_bar:
		UIThemeSetup.style_progress_bar(timer_bar, Color(0.9, 0.7, 0.2), Color(0.2, 0.18, 0.1), 2)
