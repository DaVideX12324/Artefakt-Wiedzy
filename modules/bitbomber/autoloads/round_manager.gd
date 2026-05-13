extends Node

## RoundManager — moduł BitBomber
## Zarządza rundami, wynikami graczy i triggerami quizów.
## Dostępny przez: CoreManager.get_singleton("RoundManager")

signal round_started(round_number: int)
signal round_ended(winner_id: int)
signal quiz_powerup_triggered(collector_id: int)
signal last_chance_triggered(dead_player_id: int)
signal last_chance_resolved(dead_player_id: int, respawned: bool)
signal session_ended(winner_id: int)

var round_wins: Dictionary = {}
var current_round: int = 0
var _last_chance_queue: Array[int] = []
var _last_chance_player_id: int = -1
var round_time_limit: float = 180.0
var _round_timer: float = 0.0
var _round_active: bool = false


func _process(delta: float) -> void:
	if not _round_active or round_time_limit <= 0.0:
		return
	_round_timer += delta
	if _round_timer >= round_time_limit:
		_timeout_round()


func reset_session() -> void:
	round_wins.clear()
	current_round = 0
	_round_active = false
	_round_timer = 0.0
	_last_chance_queue.clear()
	_last_chance_player_id = -1


func start_round() -> void:
	current_round += 1
	_round_timer = 0.0
	_round_active = true
	round_started.emit(current_round)


func end_round(winner_id: int) -> void:
	if not _round_active:
		return
	_round_active = false
	var gm := CoreManager.get_singleton("GameManager")
	var record_id := winner_id
	if gm and winner_id > gm.num_human_players:
		record_id = 999
	if record_id >= 0:
		round_wins[record_id] = round_wins.get(record_id, 0) + 1
	var session_winner := _compute_session_winner(record_id)
	if gm:
		gm.change_state(gm.GameState.ROUND_END)
	round_ended.emit(record_id)
	if session_winner != -2:
		if gm:
			gm.change_state(gm.GameState.GAME_OVER)
		session_ended.emit(session_winner)


func _compute_session_winner(winner_id: int) -> int:
	var gm := CoreManager.get_singleton("GameManager")
	if not gm:
		return -2
	if gm.win_condition == gm.WinCondition.FIRST_TO_X:
		if winner_id >= 0 and round_wins.get(winner_id, 0) >= gm.rounds_to_win:
			return winner_id
	elif gm.win_condition == gm.WinCondition.MOST_WINS_IN_Y:
		if current_round >= gm.max_rounds:
			var best_id := -1
			var best_wins := -1
			var tie := false
			for pid in round_wins:
				var w: int = round_wins[pid]
				if w > best_wins:
					best_wins = w ; best_id = pid ; tie = false
				elif w == best_wins:
					tie = true
			return -1 if tie else best_id
	return -2


func _timeout_round() -> void:
	_round_active = false
	end_round(-1)


func trigger_powerup_quiz(collector_id: int) -> void:
	var gm := CoreManager.get_singleton("GameManager")
	if not gm or gm.current_state != gm.GameState.PLAYING:
		return
	gm.change_state(gm.GameState.QUIZ_POWERUP)
	quiz_powerup_triggered.emit(collector_id)


func trigger_last_chance(dead_player_id: int) -> void:
	var gm := CoreManager.get_singleton("GameManager")
	if not gm:
		return
	if gm.current_state == gm.GameState.QUIZ_LAST_CHANCE:
		if not _last_chance_queue.has(dead_player_id):
			_last_chance_queue.append(dead_player_id)
		return
	if gm.current_state != gm.GameState.PLAYING:
		return
	_fire_last_chance(dead_player_id)


func _fire_last_chance(dead_player_id: int) -> void:
	_last_chance_player_id = dead_player_id
	var gm := CoreManager.get_singleton("GameManager")
	if gm:
		gm.change_state(gm.GameState.QUIZ_LAST_CHANCE)
	last_chance_triggered.emit(dead_player_id)


func resolve_last_chance(respawned: bool) -> void:
	var pid := _last_chance_player_id
	_last_chance_player_id = -1
	last_chance_resolved.emit(pid, respawned)
	if _last_chance_queue.size() > 0:
		_fire_last_chance(_last_chance_queue.pop_front() as int)
	else:
		var gm := CoreManager.get_singleton("GameManager")
		if gm:
			gm.change_state(gm.GameState.PLAYING)


func resolve_powerup_quiz() -> void:
	var gm := CoreManager.get_singleton("GameManager")
	if gm:
		gm.change_state(gm.GameState.PLAYING)


func get_wins(player_id: int) -> int:
	return round_wins.get(player_id, 0)


func get_last_chance_player() -> int:
	return _last_chance_player_id


func rounds_remaining() -> int:
	var gm := CoreManager.get_singleton("GameManager")
	if not gm:
		return 0
	match gm.win_condition:
		gm.WinCondition.FIRST_TO_X:
			var best := 0
			for pid in round_wins:
				if round_wins[pid] > best: best = round_wins[pid]
			return gm.rounds_to_win - best
		gm.WinCondition.MOST_WINS_IN_Y:
			return gm.max_rounds - current_round
		_:
			return 0
