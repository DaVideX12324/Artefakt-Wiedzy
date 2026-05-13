extends Node

## Autoload: SpriteLoader
## Ładuje i cachuje tekstury sprite’ów z dysku.
## Używany przez Player, Arena i inne węzły potrzebujące dynamicznego ładowania obrazów.

var _cache: Dictionary = {}


func get_texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("SpriteLoader: Brak zasobu '%s'" % path)
		return null
	var tex := load(path) as Texture2D
	_cache[path] = tex
	return tex


func clear_cache() -> void:
	_cache.clear()
