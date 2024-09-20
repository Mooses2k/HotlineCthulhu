@tool
# Helper class for spawning objects
class_name SpawnData
extends Resource

#- Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const ERROR_MULTIPLE_INSTANCES = "Setting the same position for multiple item instances"
const ERROR_VIRTUAL_FUNCTION = "This is a virtual function and should be overriden by a child class"

#--- public variables - order: export > normal var > onready --------------------------------------

@export var scene_path: String = ""
@export var amount: int = 1: set = _set_amount

#--- private variables - order: export > normal var > onready -------------------------------------

@export var _transforms: Array

# Array of Dictionary of properties to be applied to the spawned node, after spawn.
@export var _custom_properties: Array

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	_set_amount(1)


func _to_string() -> String:
	var msg := "[SpawnData:%s | amount: %s scene_path: %s]"%[
			get_instance_id(), amount, scene_path
	]
	for index in amount:
		var transform: Transform3D = _transforms[index]
		msg += "\n[--- %s | transform: %s]"%[index, transform]
	return msg

#--------------------------------------------------------------------------------------------------


#- Public Methods --------------------------------------------------------------------------------

## Main virtual function to be overriden by child classes, with their respective spawn logic.
func spawn_in(_node: Node, _should_log := false) -> Variant:
	push_error("SpawnData `spaw_in` called directly. %s"%[ERROR_VIRTUAL_FUNCTION])
	return null


## Sets the instance at instance_index to the center of cell_position.
func set_center_position_in_cell(cell_position: Vector3, instance_index := INF) -> void:
	if amount > 1 and instance_index == INF:
		push_warning("%s"%[ERROR_MULTIPLE_INSTANCES])
	
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform := Transform3D.IDENTITY.translated(cell_position + _get_center_offset())
		_transforms[i] = transform


## This calculates the center position of the cell and then tries to find a random position 
## around it, inside a range from min_radius to max_radius away from center
func set_random_position_in_cell(
		rng: RandomNumberGenerator,
		cell_position: Vector3, 
		min_radius: float, 
		max_radius: float, 
		p_angle := INF,
		instance_index := INF
) -> void:
	if p_angle != INF and instance_index == INF:
		push_warning("%s"%[ERROR_MULTIPLE_INSTANCES])
	
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform := _transforms[i] as Transform3D
		var angle := p_angle
		var center_position := cell_position + _get_center_offset()
		
		if angle == INF:
			angle = rng.randf_range(0.0, TAU)
		
		var radius := rng.randf_range(min_radius, max_radius)
		var random_direction := Vector3(cos(angle), 0.0, sin(angle)).normalized()
		var polar_coordinate := random_direction * radius
		var random_position := center_position + polar_coordinate
		transform = transform.translated(random_position)
		transform.basis = transform.basis.rotated(Vector3.UP, angle)
		_transforms[i] = transform


## Rotates the instance at instance_index by a random amount in each axis
func set_random_rotation_in_all_axis(
		rng: RandomNumberGenerator, 
		limit_x:= TAU, 
		limit_y := TAU, 
		limit_z := TAU, 
		instance_index := INF
) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform = _transforms[i] as Transform3D
		var axis_angle := Vector3(
			rng.randf_range(0, limit_x),
			rng.randf_range(0, limit_y),
			rng.randf_range(0, limit_z)
		)
		var random_rotation := Quaternion(axis_angle.normalized(), axis_angle.length())
		transform.basis = Basis(random_rotation)
		_transforms[i] = transform


## Sets the y axis rotation of instance at instance_index.
func set_y_rotation(angle_rad: float, instance_index := INF) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform = _transforms[i] as Transform3D
		transform.basis = transform.basis.rotated(Vector3.UP, angle_rad)
		_transforms[i] = transform


## Sets the position of instance at instance_index.
func set_position_in_cell(cell_position: Vector3, instance_index := INF) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		var transform = _transforms[i] as Transform3D
		transform.origin = cell_position
		_transforms[i] = transform


func set_custom_property(key: String, value, instance_index := INF) -> void:
	for i in amount:
		if instance_index != INF and i != instance_index:
			continue
		
		_custom_properties[i][key] = value

#--------------------------------------------------------------------------------------------------


#- Private Methods -------------------------------------------------------------------------------

func _set_amount(value: int) -> void:
	amount = int(max(1, value))
	var old_tranforms = _transforms.duplicate()
	_transforms.resize(amount)
	_custom_properties.resize(amount)
	
	_transforms.fill(Transform3D.IDENTITY)
	
	for index in _transforms.size():
		if index < old_tranforms.size() and _transforms[index] != old_tranforms[index]:
			_transforms[index] = old_tranforms[index]
		if _custom_properties[index] == null:
			_custom_properties[index] = {}


func _get_center_offset() -> Vector3:
	return Vector3.ZERO

#--------------------------------------------------------------------------------------------------


#- Signal Callbacks ------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------
