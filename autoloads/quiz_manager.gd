extends Node

## Autoload: QuizManager (wspólny dla wszystkich modułów)
## Zarządza bazą pytań quizowych, ładowaniem z JSON i walidacją odpowiedzi.
## Oddziela warstwę merytoryczną od prezentacji — pytania ładowane z plików JSON.
##
## Wszystkie pliki JSON trzymane są wspólnie w: res://resources/quizzes/
##
## Obsługiwane typy pytań (pole "type" w JSON):
##   "multiple_choice" — klasyczny wybór jednej z N odpowiedzi (domyślny)
##   "true_false"      — prawda / fałsz
##   "fill_tiles"      — uzupełnianie luk kafelkami z puli
##   "fill_text"       — wpisanie słowa/frazy (z opcjonalnym prefilled_pattern)
##   "matching"        — łączenie lewej i prawej kolumny w pary
##
## Format answer_current() — player_answer: Dictionary:
##   multiple_choice : { "index": int }
##   true_false      : { "value": bool }
##   fill_text       : { "text": String }
##   fill_tiles      : { "placements": { "0": "wartość", "1": "wartość", ... } }
##   matching        : { "pairs": [ { "left_index": int, "right_index": int }, ... ] }

signal quiz_loaded(quiz_id: String)
signal question_answered(correct: bool, question_data: Dictionary)
signal quiz_completed(quiz_id: String, score: int, total: int)

var _quizzes: Dictionary = {}            # quiz_id -> Array[Dictionary]
var _answered_questions: Dictionary = {} # question_id -> { "correct": int, "wrong": int }
var _current_quiz_id: String = ""
var _current_questions: Array = []
var _current_question_index: int = 0
var _current_score: int = 0


func _ready() -> void:
	_load_all_quizzes()


# ---------------------------------------------------------------------------
# Ładowanie quizów
# ---------------------------------------------------------------------------

func _load_all_quizzes() -> void:
	var dir = DirAccess.open("res://resources/quizzes/")
	if not dir:
		push_warning("QuizManager: Brak folderu res://resources/quizzes/")
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_quiz_file("res://resources/quizzes/" + file_name, file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()
	print("QuizManager: Załadowano %d quizów" % _quizzes.size())


func _load_quiz_file(path: String, quiz_id: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("QuizManager: Nie można otworzyć %s" % path)
		return
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()
	if result != OK:
		push_warning("QuizManager: Błąd parsowania %s" % path)
		return
	var data = json.data
	if data is Dictionary and data.has("questions"):
		_quizzes[quiz_id] = data["questions"]
	elif data is Array:
		_quizzes[quiz_id] = data


# ---------------------------------------------------------------------------
# Pobieranie pytań
# ---------------------------------------------------------------------------

## Zwraca przefiltrowaną i przetasowaną listę pytań.
## allowed_types — pusta tablica = wszystkie typy
func get_questions(
	quiz_id: String,
	difficulty_range: Vector2i = Vector2i(1, 5),
	count: int = 5,
	allowed_types: Array = []
) -> Array:
	if not _quizzes.has(quiz_id):
		push_warning("QuizManager: Quiz '%s' nie istnieje" % quiz_id)
		return []
	var all_questions: Array = _quizzes[quiz_id]
	var filtered: Array = []
	var max_diff_found := 0
	for q in all_questions:
		var diff = q.get("difficulty", 1)
		var qtype = q.get("type", "multiple_choice")
		if allowed_types.is_empty() or (qtype in allowed_types):
			max_diff_found = maxi(max_diff_found, diff)
	var actual_range = difficulty_range
	if max_diff_found > 0 and max_diff_found < difficulty_range.x:
		actual_range.y = max_diff_found
		actual_range.x = maxi(1, max_diff_found - 2)
	for q in all_questions:
		var diff = q.get("difficulty", 1)
		var qtype = q.get("type", "multiple_choice")
		if (diff >= actual_range.x and diff <= actual_range.y) \
		and (allowed_types.is_empty() or (qtype in allowed_types)):
			filtered.append(q)
	filtered.shuffle()
	if filtered.size() > count:
		filtered.resize(count)
	return filtered


# ---------------------------------------------------------------------------
# Przepływ quizu
# ---------------------------------------------------------------------------

func start_quiz(
	quiz_id: String,
	difficulty_range: Vector2i = Vector2i(1, 5),
	count: int = 5,
	allowed_types: Array = []
) -> Dictionary:
	_current_questions = get_questions(quiz_id, difficulty_range, count, allowed_types)
	_current_quiz_id = quiz_id
	_current_question_index = 0
	_current_score = 0
	if _current_questions.is_empty():
		return {}
	quiz_loaded.emit(quiz_id)
	return _current_questions[0]


func answer_current(player_answer: Dictionary) -> Dictionary:
	if _current_question_index >= _current_questions.size():
		return {}
	var question = _current_questions[_current_question_index]
	var correct := _check_answer(question, player_answer)
	if correct:
		_current_score += 1
	var qid = question.get("id", "unknown")
	if not _answered_questions.has(qid):
		_answered_questions[qid] = { "correct": 0, "wrong": 0 }
	if correct:
		_answered_questions[qid]["correct"] += 1
	else:
		_answered_questions[qid]["wrong"] += 1
	question_answered.emit(correct, question)
	_current_question_index += 1
	if _current_question_index >= _current_questions.size():
		quiz_completed.emit(_current_quiz_id, _current_score, _current_questions.size())
	return {
		"correct": correct,
		"question_type": question.get("type", "multiple_choice"),
		"correct_index": question.get("correct_index", 0),
		"correct_answer": question.get("correct_answer", null),
		"answer": question.get("answer", ""),
		"gaps": question.get("gaps", []),
		"pairs": question.get("pairs", []),
		"explanation": question.get("explanation", ""),
		"quiz_finished": _current_question_index >= _current_questions.size(),
		"score": _current_score,
		"total": _current_questions.size(),
	}


func get_current_question() -> Dictionary:
	if _current_question_index < _current_questions.size():
		return _current_questions[_current_question_index]
	return {}


func get_quiz_ids() -> Array:
	return _quizzes.keys()


# ---------------------------------------------------------------------------
# Sprawdzanie odpowiedzi
# ---------------------------------------------------------------------------

func _check_answer(question: Dictionary, player_answer: Dictionary) -> bool:
	match question.get("type", "multiple_choice"):
		"multiple_choice":
			return player_answer.get("index", -1) == question.get("correct_index", -1)
		"true_false":
			return player_answer.get("value", null) == question.get("correct_answer", null)
		"fill_text":
			var given: String = player_answer.get("text", "").strip_edges()
			var expected: String = question.get("answer", "")
			if not question.get("case_sensitive", false):
				given = given.to_lower()
				expected = expected.to_lower()
			var alts: Array = question.get("accepted_alternatives", [])
			if not question.get("case_sensitive", false):
				alts = alts.map(func(a): return a.to_lower())
			return given == expected or given in alts
		"fill_tiles":
			var placements: Dictionary = player_answer.get("placements", {})
			for gap in question.get("gaps", []):
				var idx = str(int(gap.get("index", -1)))
				if str(placements.get(idx, "")).strip_edges().to_lower() \
					!= str(gap.get("correct", "")).strip_edges().to_lower():
					return false
			return true
		"matching":
			return _compare_pairs(
				player_answer.get("pairs", []),
				question.get("pairs", [])
			)
		_:
			push_warning("QuizManager: Nieznany typ pytania '%s'" % question.get("type", ""))
			return false


func _compare_pairs(player: Array, correct: Array) -> bool:
	if player.size() != correct.size():
		return false
	for pair in correct:
		var found := false
		for p in player:
			if p.get("left_index", -1) == pair.get("left_index", -1) \
			and p.get("right_index", -1) == pair.get("right_index", -1):
				found = true
				break
		if not found:
			return false
	return true


# ---------------------------------------------------------------------------
# Statystyki
# ---------------------------------------------------------------------------

func get_accuracy_for_category(category: String) -> float:
	var correct_count := 0
	var total_count := 0
	for quiz_id in _quizzes:
		for q in _quizzes[quiz_id]:
			if q.get("category", "") == category:
				var qid = q.get("id", "")
				if _answered_questions.has(qid):
					correct_count += _answered_questions[qid]["correct"]
					total_count += _answered_questions[qid]["correct"] + _answered_questions[qid]["wrong"]
	if total_count == 0:
		return 0.5
	return float(correct_count) / float(total_count)


func get_overall_accuracy() -> float:
	var correct_count := 0
	var total_count := 0
	for qid in _answered_questions:
		correct_count += _answered_questions[qid]["correct"]
		total_count += _answered_questions[qid]["correct"] + _answered_questions[qid]["wrong"]
	if total_count == 0:
		return 0.5
	return float(correct_count) / float(total_count)


# ---------------------------------------------------------------------------
# Zapis / Reset
# ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	return { "answered_questions": _answered_questions.duplicate(true) }


func load_save_data(data: Dictionary) -> void:
	_answered_questions = data.get("answered_questions", {})


func reset() -> void:
	_answered_questions.clear()
	_current_quiz_id = ""
	_current_questions.clear()
	_current_question_index = 0
	_current_score = 0
