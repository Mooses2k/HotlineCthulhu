extends Spatial

var level : float


func _process(delta):
	var meshInstance := get_node("MeshInstance")
	get_node("ViewportContainer/Viewport/Camera").global_transform.origin = Vector3(meshInstance.global_transform.origin.x,meshInstance.global_transform.origin.y + .3, meshInstance.global_transform.origin.z)
	
	var image : Image = get_node("ViewportContainer/Viewport").get_texture().get_data()
	var floats = []
	image.lock()
	
	for y in range(0, image.get_height()):
		for x in range(0, image.get_width()):
			var pixel = image.get_pixel(x,y)
			var light_value = (pixel.r + pixel.g + pixel.b) / 3
			floats.append(light_value)
	
	level = average(floats)
	if owner.state == owner.State.STATE_CROUCHING:
		level *= (1 - pow(1 - level, 5))
	owner.light_level = level


func average(numbers: Array) -> float:
	var sum = 0.0
	for n in numbers:
		sum += n
	return sum / numbers.size()
