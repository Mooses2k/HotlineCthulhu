extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	$GammaSlider.value = VideoSettings.get_brightness()


func _on_gamma_slider_value_changed(value):
	VideoSettings.set_brightness(value)
	$WorldEnvironmentTest.environment.tonemap_exposure = value


func _on_button_pressed():
	GameManager.is_first_run = false # TODO: Save this setting
	visible = false

