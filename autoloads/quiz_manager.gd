extends Node

## Zarządza bazą pytań quizowych, ładowaniem z JSON i walidacją odpowiedzi.
## Oddziela warstwę merytoryczną od prezentacji — pytania ładowane z plików JSON.

signal quiz_loaded(quiz_id: String)
signal question_answered(correct: bool, question_data: Dictionary)
signal quiz_completed(quiz_id: String, score: int, total: int)

## Struktura pytania:
## {
##   "id": "q001",
##   "question": "Treść pytania",
##   "answers": ["A", "B", "C", "D"],
##   "correct_index": 0,
##   "difficulty": 1,        # 1-5
##   "category": "informatyka",
##   "explanation": "Opcjonalne wyjaśnienie"
## }

var _quizzes: Dictionary = {}          # quiz_id -> Array[Dictionary]
var _answered_questions: Dictionary = {} # question_id -> { correct: bool, times: int }
var _current_quiz_id: String = ""
var _current_questions: Array = []
var _current_question_index: int = 0
var _current_score: int = 0


func _ready() -> void:
	_load_all_quizzes()


## Ładuje wszystkie pliki .json z folderu res://resources/quizzes/
func _load_all_quizzes() -> void:
	var dir = DirAccess.open("res://resources/quizzes/")
	if not dir:
		push_warning("QuizManager: Brak folderu quizzes!")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var quiz_id = file_name.get_basename()
			_load_quiz_file("res://resources/quizzes/" + file_name, quiz_id)
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


## Zwraca listę pytań przefiltrowaną wg trudności
func get_questions(quiz_id: String, difficulty_range: Vector2i = Vector2i(1, 5), count: int = 5) -> Array:
	if not _quizzes.has(quiz_id):
		push_warning("QuizManager: Quiz '%s' nie istnieje" % quiz_id)
		return []

	var all_questions: Array = _quizzes[quiz_id]
	var filtered: Array = []

	for q in all_questions:
		var diff = q.get("difficulty", 1)
		if diff >= difficulty_range.x and diff <= difficulty_range.y:
			filtered.append(q)

	# Mieszaj i ogranicz
	filtered.shuffle()
	if filtered.size() > count:
		filtered.resize(count)

	return filtered


## Rozpoczyna quiz — zwraca pierwszy question lub null
func start_quiz(quiz_id: String, difficulty_range: Vector2i = Vector2i(1, 5), count: int = 5) -> Dictionary:
	_current_questions = get_questions(quiz_id, difficulty_range, count)
	_current_quiz_id = quiz_id
	_current_question_index = 0
	_current_score = 0

	if _current_questions.is_empty():
		return {}

	quiz_loaded.emit(quiz_id)
	return _current_questions[0]


## Sprawdza odpowiedź na bieżące pytanie
func answer_current(selected_index: int) -> Dictionary:
	if _current_question_index >= _current_questions.size():
		return {}

	var question = _current_questions[_current_question_index]
	var correct = (selected_index == question.get("correct_index", -1))

	if correct:
		_current_score += 1

	# Zapis statystyk pytania
	var qid = question.get("id", "unknown")
	if not _answered_questions.has(qid):
		_answered_questions[qid] = { "correct": 0, "wrong": 0 }
	if correct:
		_answered_questions[qid]["correct"] += 1
	else:
		_answered_questions[qid]["wrong"] += 1

	question_answered.emit(correct, question)

	_current_question_index += 1

	# Czy quiz się skończył?
	if _current_question_index >= _current_questions.size():
		quiz_completed.emit(_current_quiz_id, _current_score, _current_questions.size())

	return {
		"correct": correct,
		"correct_index": question.get("correct_index", 0),
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


## Statystyki do adaptacyjnej trudności
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
		return 0.5  # Domyślnie 50% jeśli brak danych
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


## --- Zapis/Odczyt ---

func get_save_data() -> Dictionary:
	return {
		"answered_questions": _answered_questions.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_answered_questions = data.get("answered_questions", {})


func reset() -> void:
	_answered_questions.clear()
	_current_quiz_id = ""
	_current_questions.clear()
	_current_question_index = 0
	_current_score = 0
