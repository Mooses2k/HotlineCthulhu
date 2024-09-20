# Write your doc string for this file here
extends Game

#- Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

@export var world_seed := 0 # (int, -55555, 55555, 1)
#export(int, -5, -1, -1) var initial_level := -1

@export var _window_size := Vector2(1280, 720)
@export var _window_position := Vector2.ZERO
@export var _screen_filter := GameManager.ScreenFilter.DEBUG_LIGHT # (GameManager.ScreenFilter)

var _is_debug_label_visible := true

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	if get_tree().current_scene == self:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# warning-ignore:return_value_discarded
		LoadQuotes.load_files()
		local_settings.add_int_setting("World Seed", -55555, 55555, 1, world_seed)
		local_settings.set_setting_group("World Seed", "Generation Settings")
		local_settings.set_setting_meta("World Seed", local_settings._CAN_RANDOMIZE_FLAG, true)
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (false) else Window.MODE_WINDOWED
		get_window().size = _window_size
		get_window().position = _window_position
		#LoadScene.setup_loadscreen()
		# warning-ignore:return_value_discarded
		LoadScene.connect("loading_screen_removed", Callable(self, "_on_LoadScene_loading_screen_removed"))
		GameManager.is_player_dead = false
		GameManager.act = 1

#--------------------------------------------------------------------------------------------------


#- Public Methods --------------------------------------------------------------------------------

func spawn_player():
	super.spawn_player()
	Events.call_deferred("emit_signal", "debug_filter_forced", _screen_filter)

#--------------------------------------------------------------------------------------------------


#- Private Methods -------------------------------------------------------------------------------

func _toggle_debug_labels() -> void:
	var event := InputEventAction.new()
	event.action = "misc|help_info"
	event.button_pressed = true
	Input.parse_input_event(event)
	_is_debug_label_visible = not _is_debug_label_visible

#--------------------------------------------------------------------------------------------------


#- Signal Callbacks ------------------------------------------------------------------------------

func _on_LoadScene_loading_screen_removed() -> void:
	if _is_debug_label_visible:
		_toggle_debug_labels()

#--------------------------------------------------------------------------------------------------
