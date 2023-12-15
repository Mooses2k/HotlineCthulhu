# Write your doc string for this file here
extends Spatial

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

enum PossibleLids {
	EMPTY,
	PLAIN,
	KNIGHT,
	SAINT,
}

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export(PossibleLids) var current_lid := PossibleLids.EMPTY setget _set_current_lid
export var transforms_by_direction := {
	WorldData.Direction.NORTH: Transform(),
}

var spawnable_items : PoolStringArray
var spawnable_items_amount : PoolIntArray
var sarco_spawnable_items : PoolStringArray
var sarco_spawnable_items_amount : PoolIntArray
var wall_direction := -1 setget _set_wall_direction

#--- private variables - order: export > normal var > onready -------------------------------------

var _current_lid_node: RigidBody = null

onready var _animation_player := $AnimationPlayer as AnimationPlayer
onready var _lid_scenes := $LidScenes as ResourcePreloader
onready var _lid_positions := {
		PossibleLids.PLAIN: $SarcophagusBase/PositionPlain,
		PossibleLids.KNIGHT: $SarcophagusBase/PositionKnight,
		PossibleLids.SAINT: $SarcophagusBase/PositionSaint,
}

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	yield(_adjust_to_wall_direction(), "completed")
	_spawn_lid()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

static func get_random_lid_type(rng: RandomNumberGenerator) -> int:
	var chosen_lid := rng.randi() % PossibleLids.keys().size()
	return chosen_lid

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _spawn_lid() -> void:
	if _current_lid_node != null:
		_current_lid_node.queue_free()
		_current_lid_node = null
	
	if current_lid == PossibleLids.EMPTY:
		return
	
	var packed_scene := _lid_scenes.get_resource(PossibleLids.keys()[current_lid]) as PackedScene
	_current_lid_node = packed_scene.instance() as RigidBody
	
	_current_lid_node.set("spawnable_items", sarco_spawnable_items)
	_current_lid_node.set("spawnable_items_amount", sarco_spawnable_items_amount)
	var spawn_node := _lid_positions[current_lid] as Position3D
	spawn_node.add_child(_current_lid_node, true)


func _set_current_lid(value: int) -> void:
	if not value in PossibleLids.values():
		push_warning("%s is not a valid Lid value."%[value])
		value = posmod(value, PossibleLids.values().size())
	current_lid = value
	
	if is_inside_tree():
		_spawn_lid()


func _set_wall_direction(value: int) -> void:
	var valid_values := [-1]
	valid_values.append_array(WorldData.Direction.values())
	if not value in valid_values:
		push_warning("%s is not a valid wall direction for sarcophagus.")
		var valid_index := posmod(value, valid_values.size())
		value = valid_values[valid_index]
	
	wall_direction = value
	
	if is_inside_tree():
		_adjust_to_wall_direction()


func _adjust_to_wall_direction() -> void:
	match wall_direction:
		WorldData.Direction.NORTH:
			_animation_player.play("north")
		WorldData.Direction.EAST:
			_animation_player.play("east")
		WorldData.Direction.SOUTH:
			_animation_player.play("south")
		WorldData.Direction.WEST:
			_animation_player.play("west")
		_:
			_animation_player.play("center")
	
	yield(_animation_player, "animation_finished")

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

# This is just to prevent errors when trying to play animation and the debug 2Tiles mesh is not
# there. At the same tame, if it is there for debugging purposes, it will be played normally.
func _on_2Tiles_tree_exiting() -> void:
	var animations := _animation_player.get_animation_list()
	for animation_name in animations:
		var animation := _animation_player.get_animation(animation_name)
		for index in range(animation.get_track_count()-1, -1, -1):
			var node_path := animation.track_get_path(index)
			if node_path.get_name(0) == "2Tiles":
				animation.remove_track(index)
	pass

### -----------------------------------------------------------------------------------------------
