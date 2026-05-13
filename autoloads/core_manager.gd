extends Node

## Autoload: CoreManager
## Naczelny menedżer ekosystemu Artefakt Wiedzy.
## Odpowiedzialny za rejestrowanie, ładowanie i zwalnianie modułów.
## Każdy moduł to osobna scena w modules/{id}/module_root.tscn,
## która w _ready() rejestruje swoje lokalne singletony przez register_singleton().

const MODULE_SCENES: Dictionary = {
	"bitbomber": "res://modules/bitbomber/module_root.tscn",
	"quiz_rpg":  "res://modules/quiz_rpg/module_root.tscn",
}

signal module_loaded(module_id: String)
signal module_unloaded(module_id: String)

var _active_module: Node = null
var _active_module_id: String = ""
var _module_singletons: Dictionary = {}  # "NazwaSingletonu" -> Node


# ---------------------------------------------------------------------------
# Ładowanie / zwalnianie modułów
# ---------------------------------------------------------------------------

func launch_module(module_id: String) -> void:
	if not MODULE_SCENES.has(module_id):
		push_error("CoreManager: Nieznany moduł '%s'" % module_id)
		return
	_unload_active()
	var scene := load(MODULE_SCENES[module_id]) as PackedScene
	if not scene:
		push_error("CoreManager: Nie można załadować sceny modułu '%s'" % module_id)
		return
	_active_module = scene.instantiate()
	_active_module_id = module_id
	get_tree().root.add_child(_active_module)
	module_loaded.emit(module_id)


func _unload_active() -> void:
	if not _active_module:
		return
	module_unloaded.emit(_active_module_id)
	_active_module.queue_free()
	_active_module = null
	_active_module_id = ""
	_module_singletons.clear()


# ---------------------------------------------------------------------------
# Rejestr singletonów per moduł
# ---------------------------------------------------------------------------

## Wywoływane przez module_root.gd każdego modułu w _ready().
func register_singleton(singleton_name: String, node: Node) -> void:
	_module_singletons[singleton_name] = node


## Pobiera lokalny singleton aktywnego modułu. Zwraca null jeśli nie znaleziono.
func get_singleton(singleton_name: String) -> Node:
	if not _module_singletons.has(singleton_name):
		push_warning("CoreManager: Brak singletonu '%s' w aktywnym module" % singleton_name)
		return null
	return _module_singletons[singleton_name]


func get_active_module_id() -> String:
	return _active_module_id


func is_module_active(module_id: String) -> bool:
	return _active_module_id == module_id
