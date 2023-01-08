extends ToolItem
class_name LanternItem


#var has_ever_been_on = true # starts on
var is_lit = true # starts on

onready var firelight = $Light
onready var burn_time = $Durability


#func _ready():
#	burn_time.start()     # done in Inspector


func _process(delta):
	if is_lit == true:
		burn_time.pause_mode = false
	else:
		burn_time.pause_mode = true
	
#	if self.mode == equipped_mode and has_ever_been_on == false:
##			burn_time.start()   # done in Inspector
#			has_ever_been_on = true
#			firelight.visible = true
#			$MeshInstance.cast_shadow = false
#			is_lit = true
#	else:
#		is_lit = false


func light():
	$AnimationPlayer.play("flicker")
	$LightSound.play()
	firelight.visible = true
	$MeshInstance.cast_shadow = false
	is_lit = true


func unlight():
	$AnimationPlayer.stop()
	$BlowOutSound.play()
	firelight.visible = false
	$MeshInstance.cast_shadow = true
	is_lit = false


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()


func _on_Durability_timeout():
	unlight()
