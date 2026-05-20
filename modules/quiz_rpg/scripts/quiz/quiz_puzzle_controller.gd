extends Control

## UI zagadki quizowej — drzwi/przejścia.
## Różni się od walki: nie ma HP wroga, jest progress bar "odblokowania".

signal puzzle_finished(success: bool)

var door: Node2D
var player: Node2D
var required_correct: int = 3
var current_correct: int = 0
var current_question: int = 0
var total_questions: int = 5
var _answering: bool = false

var _quiz_id: String
var _category: String

var question_label: RichTextLabel
var answer_buttons: Array[Button] = []
var feedback_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var title_label: Label

# Singletony
var _ps: Node   # PlayerStats
var _dm: Node   # DifficultyManager


func setup(p_door: Node2D, p_player: Node2D, quiz_id: String,
		category: String, p_total: int, p_required: int) -> void:
	door = p_door
	player = p_player
	_quiz_id = quiz_id
	_category = category
	total_questions = p_total
	required_correct = p_required


func _ready() -> void:
	_ps = CoreManager.get_singleton("PlayerStats")
	_dm = CoreManager.get_singleton("DifficultyManager")

	question_label = $Panel/MarginContainer/VBoxContainer/QuestionLabel
	answer_buttons = [
		$Panel/MarginContainer/VBoxContainer/AnswersGrid/AnswerBtn0,
		$Panel/MarginContainer/VBoxContainer/AnswersGrid/AnswerBtn1,
		$Panel/MarginContainer/VBoxContainer/AnswersGrid/AnswerBtn2,
		$Panel/MarginContainer/VBoxContainer/AnswersGrid/AnswerBtn3,
	]
	feedback_label = $Panel/MarginContainer/VBoxContainer/FeedbackLabel
	progress_bar   = $Panel/MarginContainer/VBoxContainer/ProgressBar
	progress_label = $Panel/MarginContainer/VBoxContainer/ProgressLabel
	title_label    = $Panel/MarginContainer/VBoxContainer/TitleLabel

	UIThemeSetup.style_quiz_ui(self)

	for i in range(answer_buttons.size()):
		answer_buttons[i].pressed.connect(_on_answer_pressed.bind(i))

	if title_label:
		if door and "door_name" in door:
			title_label.text = "🔒 " + door.door_name
		else:
			title_label.text = "🔒 Zagadka"

	var diff_range := Vector2i(1, 3)
	if _dm:
		diff_range = _dm.get_difficulty_range(_category)

	var first_q: Dictionary = QuizManager.start_quiz(_quiz_id, diff_range, total_questions)

	if first_q.is_empty():
		push_warning("QuizPuzzle: Brak pytań!")
		puzzle_finished.emit(false)
		queue_free()
		return

	_update_progress()
	_show_question(first_q)


func _show_question(q: Dictionary) -> void:
	_answering = true
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

	feedback_label.text = ""


func _on_answer_pressed(index: int) -> void:
	if not _answering:
		return
	_answering = false

	var result: Dictionary = QuizManager.answer_current({"index": index})
	var correct: bool = result.get("correct", false)
	var correct_idx: int = result.get("correct_index", 0)
	var category: String = _category if _category != "" else "ogolne"

	for i in range(4):
		answer_buttons[i].disabled = true
	answer_buttons[correct_idx].add_theme_color_override("font_color", Color.GREEN)

	if correct:
		current_correct += 1
		if _ps:
			_ps.on_correct_answer()
		if _dm:
			_dm.record_answer(category, true)
		feedback_label.text = "✓ Poprawnie!"
		feedback_label.add_theme_color_override("font_color", Color.GREEN)

		if _ps and _ps.roll_with_bonus(0.15):
			current_correct += 1
			feedback_label.text += " (Bonus! +1 postęp)"
	else:
		if index >= 0 and index < answer_buttons.size():
			answer_buttons[index].add_theme_color_override("font_color", Color.RED)
		if _ps:
			_ps.on_wrong_answer()
		if _dm:
			_dm.record_answer(category, false)
		feedback_label.text = "✗ Źle! " + result.get("explanation", "")
		feedback_label.add_theme_color_override("font_color", Color.RED)

	current_question += 1
	_update_progress()

	await get_tree().create_timer(1.2).timeout

	if current_correct >= required_correct:
		_finish(true)
	elif current_question >= total_questions:
		_finish(current_correct >= required_correct)
	elif result.get("quiz_finished", false):
		_finish(current_correct >= required_correct)
	else:
		var next_q: Dictionary = QuizManager.get_current_question()
		if not next_q.is_empty():
			_show_question(next_q)
		else:
			_finish(current_correct >= required_correct)


func _update_progress() -> void:
	if progress_bar:
		progress_bar.value = (float(current_correct) / float(required_correct)) * 100.0
	if progress_label:
		progress_label.text = "%d / %d poprawnych odpowiedzi" % [current_correct, required_correct]


func _finish(success: bool) -> void:
	if success:
		feedback_label.text = "🔓 Otwarto!"
		feedback_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		feedback_label.text = "🔒 Nie udało się otworzyć..."
		feedback_label.add_theme_color_override("font_color", Color.RED)

	await get_tree().create_timer(1.0).timeout
	puzzle_finished.emit(success)
	get_parent().queue_free()
