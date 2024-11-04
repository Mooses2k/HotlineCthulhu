class_name SoundSensor extends CharacterSense


signal sound_detected(source, interest)

const WALL_NAMES := ["wall_xp", "wall_zp", "wall_xn", "wall_zn", "ceiling", "ground"]

@export var check_frame_interval := 10
@export var hearing_sensitivity := 5.0

var sound_sources := []


func _ready() -> void:
	connect("body_entered", Callable(self, "on_body_entered"))
	connect("body_exited", Callable(self, "on_body_exited"))
	collision_mask = 1 << 1 | 1 << 6 | 1 << 9
	collision_layer = 0


func on_body_entered(body: Node3D) -> void:
	if !(body is Character or body is PickableItem or body is LargeObject): return
	if !sound_sources.has(body): sound_sources.append(body)


func on_body_exited(body: Node3D) -> void:
	if sound_sources.has(body):
		sound_sources.erase(body)


func tick(_character: HumanoidCharacter, _delta: float) -> int:
	return OK if check_for_sounds() else FAILED


func check_for_sounds() -> bool:   # changed to bool during migration
	for object in sound_sources:
		var interest_level := get_interest_level(object)
		if !interest_level: continue

		emit_signal("sound_detected", object, interest_level)
		emit_signal("event", interest_level, object.global_transform.origin, object, self)
		return true   # this and next return line added during migration to fix error
	return false


func get_interest_level(source: Node3D) -> int:
	if !(source is Character or source is PickableItem or source is LargeObject): return 0
	if !source.noise_level: return 0

	var interest := source.noise_level as int
	var walls_in_between := get_walls_in_between(source.global_transform.origin)
	if walls_in_between: interest /= walls_in_between

	var distance := global_transform.origin.distance_to(source.global_transform.origin)
	if source is BombItem and interest >= 80: interest += 100
	if distance < 1.0: interest += 100

	return interest if interest >= hearing_sensitivity else 0


func get_walls_in_between(target_position : Vector3) -> int:
	var shape := SeparationRayShape3D.new()
	shape.length = global_transform.origin.distance_to(target_position)

	var shape_params := PhysicsShapeQueryParameters3D.new()
	shape_params.transform = Transform3D(global_transform).looking_at(-to_local(target_position), Vector3.UP)
	shape_params.collision_mask = 1 << 0
	shape_params.set_shape(shape)

	return get_world_3d().direct_space_state.intersect_shape(shape_params).size()
