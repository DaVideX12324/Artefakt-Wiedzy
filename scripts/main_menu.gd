extends CanvasLayer
## Menu glowne ekosystemu Artefakt Wiedzy.
## Launchuje wybrane moduly przez CoreManager.

@onready var _panel        : PanelContainer  = $Center/Panel
@onready var _margin       : MarginContainer = $Center/Panel/Margin
@onready var _vbox         : VBoxContainer   = $Center/Panel/Margin/VBox
@onready var _title        : Label           = $Center/Panel/Margin/VBox/Title
@onready var _subtitle     : Label           = $Center/Panel/Margin/VBox/Subtitle
@onready var _btn_bb       : Button          = $Center/Panel/Margin/VBox/BtnBitBomber
@onready var _btn_qrpg     : Button          = $Center/Panel/Margin/VBox/BtnQuizRPG
@onready var _btn_options  : Button          = $Center/Panel/Margin/VBox/HBoxMeta/BtnOptions
@onready var _btn_quit     : Button          = $Center/Panel/Margin/VBox/HBoxMeta/BtnQuit
@onready var _ver_label    : Label           = $VerLabel
@onready var _options_menu : CanvasLayer     = $OptionsMenu

const BASE_PANEL_MIN_W   := 320.0
const BASE_PANEL_PADDING := 20
const BASE_SEP_VBOX      := 12
const BASE_BTN_MODULE    := Vector2(320.0, 56.0)
const BASE_BTN_META      := Vector2(154.0, 36.0)


func _ready() -> void:
	_btn_bb.pressed.connect(_on_launch_bitbomber)
	_btn_qrpg.pressed.connect(_on_launch_quiz_rpg)
	_btn_options.pressed.connect(_on_options)
	_btn_quit.pressed.connect(_on_quit)

	_btn_bb.text      = "\U0001F4A3 BitBomber\nGra edukacyjna bomberman"
	_btn_qrpg.text    = "\U0001F4D6 Quiz RPG\nUcz sie, zdobywaj XP"
	_btn_options.text = "\u2699 Ustawienia"
	_btn_quit.text    = "\u2715 Wyjscie"

	CoreManager.module_unloaded.connect(_on_module_unloaded)

	UIScaleManager.scale_changed.connect(_on_scale_changed)
	_on_scale_changed(UIScaleManager.scale_factor)


# ---------------------------------------------------------------------------
# Skalowanie
# ---------------------------------------------------------------------------

func _on_scale_changed(_s: float) -> void:
	_panel.custom_minimum_size = Vector2(UIScaleManager.sz(BASE_PANEL_MIN_W), 0)
	_vbox.add_theme_constant_override("separation", UIScaleManager.px(BASE_SEP_VBOX))

	_title.add_theme_font_size_override("font_size",    UIScaleManager.px(32))
	_subtitle.add_theme_font_size_override("font_size", UIScaleManager.px(14))
	_ver_label.add_theme_font_size_override("font_size", UIScaleManager.px(11))

	_btn_bb.add_theme_font_size_override("font_size",      UIScaleManager.px(18))
	_btn_qrpg.add_theme_font_size_override("font_size",    UIScaleManager.px(18))
	_btn_options.add_theme_font_size_override("font_size", UIScaleManager.px(17))
	_btn_quit.add_theme_font_size_override("font_size",    UIScaleManager.px(17))

	_btn_bb.custom_minimum_size   = UIScaleManager.sz2(BASE_BTN_MODULE.x, BASE_BTN_MODULE.y)
	_btn_qrpg.custom_minimum_size = UIScaleManager.sz2(BASE_BTN_MODULE.x, BASE_BTN_MODULE.y)
	_btn_options.custom_minimum_size = UIScaleManager.sz2(BASE_BTN_META.x, BASE_BTN_META.y)
	_btn_quit.custom_minimum_size    = UIScaleManager.sz2(BASE_BTN_META.x, BASE_BTN_META.y)

	var pad := UIScaleManager.px(BASE_PANEL_PADDING)
	_margin.add_theme_constant_override("margin_left",   pad)
	_margin.add_theme_constant_override("margin_top",    pad)
	_margin.add_theme_constant_override("margin_right",  pad)
	_margin.add_theme_constant_override("margin_bottom", pad)


# ---------------------------------------------------------------------------
# Akcje
# ---------------------------------------------------------------------------

func _on_launch_bitbomber() -> void:
	_hide_menu()
	CoreManager.launch_module("bitbomber")


func _on_launch_quiz_rpg() -> void:
	_hide_menu()
	CoreManager.launch_module("quiz_rpg")


func _on_options() -> void:
	_options_menu.open()


func _on_quit() -> void:
	get_tree().quit()


func _on_module_unloaded(_module_id: String) -> void:
	_show_menu()


func _hide_menu() -> void:
	visible = false


func _show_menu() -> void:
	visible = true
