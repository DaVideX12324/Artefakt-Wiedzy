extends Node

## DifficultyManager — moduł QuizRPG
## Adaptacyjna trudność — dostosowuje poziom pytań do umiejętności gracza.
## Dostępny przez: CoreManager.get_singleton("DifficultyManager")

signal difficulty_adjusted(category: String, new_level: int)

const MIN_DIFFICULTY := 1
const MAX_DIFFICULTY := 5
const WINDOW_SIZE    := 10
const THRESHOLD_UP   := 0.8
const THRESHOLD_DOWN := 0.4

var _difficulty_levels: Dictionary = {}
var _recent_answers: Dictionary = {}


func get_difficulty(category: String) -> int:
	return _difficulty_levels.get(category, 2)


func get_difficulty_range(category: String) -> Vector2i:
	var base = get_difficulty(category)
	return Vector2i(maxi(base - 1, MIN_DIFFICULTY), mini(base + 1, MAX_DIFFICULTY))


func record_answer(category: String, correct: bool) -> void:
	if not _recent_answers.has(category):
		_recent_answers[category] = []
	_recent_answers[category].append(correct)
	if _recent_answers[category].size() > WINDOW_SIZE:
		_recent_answers[category].pop_front()
	_evaluate_difficulty(category)


func _evaluate_difficulty(category: String) -> void:
	var answers: Array = _recent_answers.get(category, [])
	if answers.size() < 5:
		return
	var correct_count := 0
	for a in answers:
		if a: correct_count += 1
	var accuracy = float(correct_count) / float(answers.size())
	var current = get_difficulty(category)
	var new_diff = current
	if accuracy >= THRESHOLD_UP and current < MAX_DIFFICULTY:
		new_diff = current + 1
		_recent_answers[category].clear()
	elif accuracy <= THRESHOLD_DOWN and current > MIN_DIFFICULTY:
		new_diff = current - 1
		_recent_answers[category].clear()
	if new_diff != current:
		_difficulty_levels[category] = new_diff
		difficulty_adjusted.emit(category, new_diff)


func get_global_difficulty() -> float:
	if _difficulty_levels.is_empty():
		return 2.0
	var total := 0
	for cat in _difficulty_levels:
		total += _difficulty_levels[cat]
	return float(total) / float(_difficulty_levels.size())


func get_save_data() -> Dictionary:
	return {
		"difficulty_levels": _difficulty_levels.duplicate(),
		"recent_answers":    _recent_answers.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_difficulty_levels = data.get("difficulty_levels", {})
	_recent_answers    = data.get("recent_answers", {})


func reset() -> void:
	_difficulty_levels.clear()
	_recent_answers.clear()
