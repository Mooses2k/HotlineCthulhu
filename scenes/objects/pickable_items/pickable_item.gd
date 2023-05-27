extends RigidBody
class_name PickableItem


signal item_state_changed(previous_state, current_state)

export(int, LAYERS_3D_PHYSICS) var dropped_layers : int = 0
export(int, LAYERS_3D_PHYSICS) var dropped_mask : int = 0
export(int, "Rigid", "Static", "Character", "Kinematic") var dropped_mode : int = MODE_RIGID

export(int, LAYERS_3D_PHYSICS) var equipped_layers : int = 0
export(int, LAYERS_3D_PHYSICS) var equipped_mask : int = 0
export(int, "Rigid", "Static", "Character", "Kinematic") var equipped_mode : int = MODE_KINEMATIC

export var max_speed : float = 12.0

#onready var mesh_instance = $MeshInstance
var owner_character : Node = null
var item_state = GlobalConsts.ItemState.DROPPED setget set_item_state
onready var audio_player = get_node("DropSound")
export var item_drop_sound : AudioStream
var noise_level = 0   # noise detectable by characters
var item_max_noise_level = 5
var item_sound_level = 10


func _enter_tree():
	if not audio_player:
		var drop_sound = AudioStreamPlayer3D.new()
		drop_sound.name = "DropSound"
		add_child(drop_sound)
	
	match self.item_state:
		GlobalConsts.ItemState.DROPPED:
			set_physics_dropped()
		GlobalConsts.ItemState.INVENTORY:
			set_physics_equipped()
		GlobalConsts.ItemState.EQUIPPED:
			set_physics_equipped()


func _process(delta):
	if self.noise_level > 0:
		yield(get_tree().create_timer(0.2), "timeout")
		self.noise_level = 0


func set_item_state(value : int) :
	var previous = item_state
	item_state = value
	emit_signal("item_state_changed", previous, item_state)


func play_drop_sound(body):
	if self.item_drop_sound and self.audio_player:
		self.audio_player.stream = self.item_drop_sound
		self.audio_player.unit_db = item_sound_level
		self.audio_player.play()
		self.noise_level = item_max_noise_level


func set_physics_dropped():
	self.collision_layer = dropped_layers
	self.collision_mask = dropped_mask
	self.mode = dropped_mode


func set_physics_equipped():
	self.collision_layer = equipped_layers
	self.collision_mask = equipped_mask
	self.mode = equipped_mode


func _integrate_forces(state):
	if item_state == GlobalConsts.ItemState.DROPPED:
		state.linear_velocity = state.linear_velocity.normalized()*min(state.linear_velocity.length(), max_speed)


#func pickup(by : Node):
#	self.item_state = ItemState.INVENTORY
#	if self.is_inside_tree():
#		get_parent().call_deferred("remove_child", self)
#		yield(self, "tree_exited")
#	set_physics_equipped()
#	self.owner_character = by


#func drop(at : Transform):
#	self.item_state = ItemState.DROPPED
#	if self.get_parent():
#		get_parent().call_deferred("remove_child", self)
#		yield(self, "tree_exited")
#	set_physics_dropped()
#	self.owner_character = null
#	if GameManager.game.level:
#		self.global_transform = at
##		self.linear_velocity = at.basis.x
#		GameManager.game.level.call_deferred("add_child", self)
#		yield(self, "tree_entered")
#		self.force_update_transform()
#	else:
#		printerr(self, " has disappeared into the void: no Level was found")
#		self.free()
