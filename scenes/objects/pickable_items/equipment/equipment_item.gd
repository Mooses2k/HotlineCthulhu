class_name EquipmentItem
extends PickableItem


signal used_primary()
signal used_secondary()
signal used_reload()

export (bool) var can_attach = false
export(GlobalConsts.ItemSize) var item_size : int = GlobalConsts.ItemSize.SIZE_MEDIUM

export var item_name : String = "Equipment"
export var horizontal_holding : bool = false

export var normal_pos_path : NodePath
onready var normal_pos = get_node(normal_pos_path)
export var throw_pos_path : NodePath
onready var throw_pos = get_node(throw_pos_path)
export var throw_logic : bool   # Some items like swords should be thrown point first
export var can_spin : bool   # Some items when thrown should spin

var is_in_belt = false
var has_equipped = false
onready var hold_position = $"%HoldPosition"


func _ready():
	if horizontal_holding == true:
		hold_position.rotation_degrees.z = 90
		
	connect("body_entered", self, "play_drop_sound")


func _process(delta):
	pass
#	if throw_logic:
#		if item_state == GlobalConsts.ItemState.EQUIPPED:
#			self.global_rotation = normal_pos.global_rotation


## WORKAROUND for https://github.com/godotengine/godot/issues/62435
# Bug here where when player rotates, items does a little circle thing in hand
func _physics_process(delta):
	if self.item_state == GlobalConsts.ItemState.EQUIPPED:
		transform = get_hold_transform()


# Override this function for (Left-Click and E, typically) use actions
func _use_primary():
	print("use primary")
	pass


# Right-click, typically
func _use_secondary():
	print("use secondary")
	pass


# Reloads can only happen in main-hand
func _use_reload():
	print("use reload")
	pass


func use_primary():
	_use_primary()
	emit_signal("used_primary")


func use_secondary():
	_use_secondary()
	emit_signal("used_secondary")


func use_reload():
	_use_reload()
	emit_signal("used_reload")


func get_hold_transform() -> Transform:
	return $HoldPosition.transform.inverse()


func apply_throw_logic():
	if throw_logic:
		self.global_rotation = throw_pos.global_rotation   # This attempts to align the point forward when throwing piercing weapons
	if can_spin:
		angular_velocity = Vector3(global_transform.basis.x * -15)
#		angular_velocity.z = -15   # Ah, maybe not working because it's already been put in world_space at this point
