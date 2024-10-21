extends "setting_editor.gd"


#Override this function
func _get_value():
	return %Value.value


#Override this function
func _set_value(value):
	%Value.value = value


#Override this function
func _on_value_edited():
	var new_value = get_value()
	%Display.text = str(get_value())
	if new_value != settings.get_setting(_setting_name):
		settings.set_setting(_setting_name, new_value)


#Override this function
func _on_setting_attached():
	%Value.min_value = settings.get_setting_min_value(_setting_name)
	%Value.max_value = settings.get_setting_max_value(_setting_name)
	%Value.step = settings.get_setting_step(_setting_name)
#	%Value.connect("value_changed", self, "on_value_edited")
	if _setting_name.contains('|'):
		%Name.text = _setting_name.split('|')[1]
	else:
		%Name.text = _setting_name
	%Display.text = str(get_value())
	%Value.connect("value_changed", Callable(self, "_on_Value_value_changed"))   # in order to respect default value


func _on_Value_value_changed(value):
	on_value_edited()
