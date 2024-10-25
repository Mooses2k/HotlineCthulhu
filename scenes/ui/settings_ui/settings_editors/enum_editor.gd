extends "setting_editor.gd"


#Override this function
func _get_value():
	return %Value.selected


#Override this function
func _set_value(value):
	%Value.selected = value


#Override this function
func _on_value_edited():
	var new_value = get_value()
	if new_value != settings.get_setting(_setting_name):
		settings.set_setting(_setting_name, new_value)


#Override this function
func _on_setting_attached():
#	%Value.connect("value_changed", self, "on_value_edited")
	if _setting_name.contains('|'):
			%Name.text = _setting_name.split('|')[1]
	else:
		%Name.text = _setting_name
	var options = settings.get_setting_variants(_setting_name)
	for i in options.size():
		%Value.add_item(options[i], i)


func _on_Value_item_selected(index):
	on_value_edited()
