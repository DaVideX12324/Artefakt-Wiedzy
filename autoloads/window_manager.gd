extends Node

## Autoload: WindowManager
## Pomocnicze utility do operacji na oknie gry.
## Uzupełnia SettingsManager o drobne operacje nie wymagające zapisu.


func center_on_screen(screen: int = -1) -> void:
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	var screen_pos  := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	var win_size    := DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen_pos + (screen_size - win_size) / 2)


func get_current_screen() -> int:
	return DisplayServer.window_get_current_screen()


func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
