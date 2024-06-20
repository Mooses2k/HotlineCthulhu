class_name Character
extends CharacterBody3D

# TODO: This script is a dog's dinner - needs total redesign


signal character_died()
signal is_hit(current_health)
signal is_moving(is_player_moving)
signal player_landed()
const PI_BY_FOUR = PI / 4

var _alive : bool = true
var _type_damage_multiplier : PackedByteArray
@export var immunities : Array # (Array, AttackTypes.Types)
@export var max_health : int = 100
@onready var current_health : int = self.max_health

@export var move_speed : float = 7.0
@export var acceleration : float = 32.0
@export var mass : float = 80.0

@onready var kick_timer = $Legs/KickTimer   # Later, this should replaced by animations
@export var _legcast : NodePath

@export var kick_damage : int = 15   # 3 kicks for a cultist, 5 for a door to start with?
@export var kick_impulse : float = 7
@export var kick_max_speed : float = 10.0
@export var kick_damage_type : int = 0 # (AttackTypes.Types)
#export(AttackTypes.Types) var damage_type : int = 0

@export var animation_tree_path : NodePath

enum ItemSelection {
	ITEM_MAINHAND,
	ITEM_OFFHAND,
}

#enum ThrowState {
#	IDLE,
#	PRESSING,
#	SHOULD_PLACE,
#	SHOULD_THROW,
#}

# For player-heard audio and for sound propogation to other characters' sensors
enum SurfaceType {
	WOOD,
	CARPET,
	STONE,
	WATER,
	GRAVEL,
	METAL, 
	TILE
}

# States from stealth player controller addon
enum MovementState {
	STATE_WALKING,
	STATE_LEANING,
	STATE_CROUCHING,
	STATE_CRAWLING,
	STATE_CLAMBERING_RISE,
	STATE_CLAMBERING_LEDGE,
	STATE_CLAMBERING_VENT,
	STATE_NOCLIP,
}

# Checks if the player is equipping something or not 
# TODO: this needs to be removed and merged into HoldStates below so that it's the same as HoldStates in player_anims
enum AnimationState {
	EQUIPPED,
	NOT_EQUIPPED,
}

enum HoldStates {
	SMALL_GUN_ITEM,
	LARGE_GUN_ITEM,
	MELEE_ITEM,
	ITEM_HORIZONTAL,
	SMALL_GUN_ADS,
	LARGE_GUNS_ADS,
}

var mainhand_animation = AnimationState.NOT_EQUIPPED
var current_mainhand_item_animation = HoldStates.MELEE_ITEM

#const TEXTURE_SOUND_LIB = {
#	"checkerboard" : {
#		"amplifier" : 5.0,
#		"sfx_folder" : "resources/sounds/footsteps/footsteps"
#	}
#}

@export var gravity : float = 10.0
@export var crouch_rate = 0.08 # (float, 0.05, 1.0)
@export var crawl_rate = 0.5 # (float, 0.1, 1.0)
@export var move_drag : float = 0.2
#export(float, -45.0, -8.0, 1.0) var max_lean = -10.0
@export var interact_distance : float = 0.75

var movement_state = MovementState.STATE_WALKING

var light_level : float = 0.0

#var velocity : Vector3 = Vector3.ZERO
var _current_velocity : Vector3 = Vector3.ZERO

var stamina := 600.0

#var current_control_mode_index = 0
#onready var current_control_mode : ControlMode = get_child(0)

var wanna_stand : bool = false
var is_crouching : bool = false
var can_stand : bool = false
var is_player_crouch_toggle : bool = true
var do_crouch : bool = false

var grab_press_length : float = 0.0
var wanna_grab : bool = false
var is_grabbing : bool = false
var interaction_handled : bool = false
var grab_object : RigidBody3D = null
var grab_relative_object_position : Vector3
var grab_distance : float = 0
var drag_object : RigidBody3D = null
#var current_object = null

var wants_to_drop = false
var crouch_equipment_target_pos = 0.663
var equipment_orig_pos : float

var clamber_destination : Vector3 = Vector3.ZERO
var _clamber_m = null
var clamber_target
var is_clambering : bool = false
var clamberable_obj # : RigidBody3D      # Commented to allow static bodies too
var is_clamberable # : RigidBody3D = null   # Commented to allow static bodies too
var default_clamber_speed : float = 0.1   # Added to allow encumbrance to slow clambering.

var is_player_moving : bool = false
var is_moving_forward : bool = false
var is_to_move : bool = true
var move_dir = Vector3()
var do_sprint : bool = false

@export var jump_force : float = 3.5
var grounded = false
var do_jump : bool = false
var is_jumping : bool = false

var low_kick : bool = false   # Should we do a low kick instead of a mid-height stomp kick?

var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else

var is_reloading = false

@onready var state := CharacterState.new(self)

@onready var skeleton = %Skeleton3D
@onready var inventory = $Inventory
@onready var mainhand_equipment_root = %MainHandEquipmentRoot
@onready var offhand_equipment_root = %OffHandEquipmentRoot
@onready var belt_position = %BeltPosition

@onready var drop_position_node = $Body/DropPosition as Node3D
@onready var throw_position_node = %ThrowPosition as Node3D

@onready var character_body = $Body   # Don't name this just plain 'body' unless you want bugs with collisions
@onready var animation_tree = %AnimationTree
@onready var additional_animations  = $AdditionalAnimations

@onready var _camera = get_node("FPSCamera")
@onready var _collider = get_node("CollisionShape3D")
@onready var _crouch_collider = get_node("CollisionShape2")
@onready var _surface_detector = get_node("SurfaceDetector")
@onready var _sound_emitter = get_node("SoundEmitter")
@onready var _audio_player = get_node("Audio")
@onready var _character_hitbox = get_node("CanStandChecker")
@onready var _ground_checker = %GroundChecker
@onready var legcast : RayCast3D = get_node(_legcast) as RayCast3D
@onready var _speech_player = get_node("Audio/Speech")

@onready var item_drop_sound_flesh : AudioStream = load("res://resources/sounds/impacts/blade_to_flesh/blade_to_flesh.wav")
@onready var kick_sound : AudioStream = load("res://resources/sounds/throwing/346373__denao270__throwing-whip-effect.wav")


func _ready():
	_type_damage_multiplier.resize(AttackTypes.Types._COUNT)
	for i in _type_damage_multiplier.size():
		_type_damage_multiplier[i] = 1
	for immunity in self.immunities:
		_type_damage_multiplier[immunity] = 0
	
	_clamber_m = ClamberManager.new(self, _camera, get_world_3d())
	equipment_orig_pos = mainhand_equipment_root.transform.origin.y


func _physics_process(delta : float):
	if !_alive:
		return
	
	if animation_tree != null:
		check_state_animation(delta)
		check_current_item_animation()
	can_stand = true
	for body in _character_hitbox.get_overlapping_bodies():
		if body is RigidBody3D:
			can_stand = false
	
	interaction_handled = false
	
	if wanna_stand:
		if _collider.disabled:
			_collider.set_deferred("disabled", false)
			_crouch_collider.set_deferred("disabled", true)
			
		var from = mainhand_equipment_root.transform.origin.y
		mainhand_equipment_root.transform.origin.y = lerp(from, equipment_orig_pos, 0.08)
		
		from = offhand_equipment_root.transform.origin.y
		offhand_equipment_root.transform.origin.y = lerp(from, equipment_orig_pos, 0.08)
		var d1 = mainhand_equipment_root.transform.origin.y - equipment_orig_pos
		if d1 > -0.04:
			mainhand_equipment_root.transform.origin.y = equipment_orig_pos
			offhand_equipment_root.transform.origin.y = equipment_orig_pos
			
	match movement_state:
		MovementState.STATE_WALKING:
			_walk(delta)
			
		MovementState.STATE_CROUCHING:
			if !do_crouch and is_player_crouch_toggle:
				if do_sprint or (is_crouching and can_stand):
					is_crouching = false
					wanna_stand = true
					movement_state = MovementState.STATE_WALKING
					return
					
			is_crouching = true
			_crouch(delta)
			_walk(delta, 0.75)
			
		MovementState.STATE_CLAMBERING_RISE:
			var pos = global_transform.origin
			var clamber_target = Vector3(pos.x, clamber_destination.y, pos.z)
			# Clamber speed affected by encumbrance
			var clamber_speed = default_clamber_speed / (1 + inventory.encumbrance)
			global_transform.origin = lerp(pos, clamber_target, clamber_speed)
			
			var d = pos - clamber_target
			if d.length() < 0.1:
				movement_state = MovementState.STATE_CLAMBERING_LEDGE
				return
				
		MovementState.STATE_CLAMBERING_LEDGE:
			#_audio_player.play_clamber_sound(false)
			var pos = global_transform.origin
			# Clamber speed affected by encumbrance
			var clamber_speed = default_clamber_speed / (1 + inventory.encumbrance)
			global_transform.origin = lerp(pos, clamber_destination, clamber_speed)
			
			var d = global_transform.origin - clamber_destination
			if d.length() < 0.1:
				is_clambering = false
				global_transform.origin = clamber_destination
				if clamberable_obj and clamberable_obj is RigidBody3D:   # Altered to allow statics
					clamberable_obj.mode = 0
					
				if is_crouching:
					movement_state = MovementState.STATE_CROUCHING
					return
				movement_state = MovementState.STATE_WALKING
				return
	move_effect()


# I believe this is for a RigidBody style controller we used to have; we can keep for now
#func slow_down(state : PhysicsDirectBodyState):
#	state.linear_velocity = state.linear_velocity.normalized() * min(state.linear_velocity.length(), move_speed)


func kick():
	#prints("Kick timer stopped:", kick_timer.is_stopped())
	#prints("legcast colliding:", legcast.is_colliding())
	if kick_timer.is_stopped() and legcast.is_colliding() and stamina > 50:
		var kick_object = legcast.get_collider()
		if is_instance_valid(_camera):
			_camera.add_stress(0.5)
		kick_timer.start()
		stamina -= 50
		
		if kick_object is DoorInteractable and is_grabbing == false:
			kick_object.emit_signal("kicked", legcast.get_collision_point(), -global_transform.basis.z, kick_damage)
			
		elif kick_object.is_in_group("CHARACTER"):
			kick_object.get_parent().damage(kick_damage, kick_damage_type , kick_object)
			$"Audio/Movement".stream = item_drop_sound_flesh
			$"Audio/Movement".play()
		
		elif (kick_object is RigidBody3D or kick_object.is_in_group("IGNITE")):
			if kick_object is Area3D:
				kick_object = kick_object.get_parent()   # You just kicked the IGNITE area
#			print(kick_object.get_class())
			var actual_kick_impulse = min(kick_impulse, kick_object.mass * kick_max_speed)
			if kick_object is PickableItem:   # Is a large object like a floor candelabra
				kick_object.apply_central_impulse(-global_transform.basis.z * actual_kick_impulse)
				kick_object.play_drop_sound(kick_object)
			elif kick_object.has_method("play_drop_sound"):   # Is probably a PickableItem
				kick_object.apply_central_impulse(-global_transform.basis.z * actual_kick_impulse)
				kick_object.play_drop_sound(10, false)
	else:
		kick_timer.start()
		stamina -= 50
		$"Audio/Movement".stream = kick_sound
		$"Audio/Movement".play()


func damage(value : int, type : int, on_hitbox : Hitbox):
	if self._alive:
		self.current_health -= self._type_damage_multiplier[type] * value
		self.emit_signal("is_hit", current_health)
		$Audio/Movement.stream = item_drop_sound_flesh
		$Audio/Movement.play()
		
		if self.current_health <= 0:
			self._alive = false
			self.emit_signal("character_died")
			
			if self.name != "Player":
				_collider.disabled = true
				_crouch_collider.disabled = true
				print("Character died")
				self.inventory.drop_mainhand_item()
				self.inventory.drop_offhand_item()
				
#				self.queue_free()
				skeleton.physical_bones_start_simulation()   # This ragdolls
				if is_instance_valid($Audio/Speech):
					$Audio/Speech.volume_db = -80
					$Audio/Speech.stop()
				# This is to make the infinite spawner on DLvl -5 work
				# If in the future, they can somehow come back alive, change this or readd them to the group
				if is_in_group("CULTIST"):
					remove_from_group("CULTIST")


func heal(amount):
	current_health += amount
	if current_health > max_health:
		current_health = max_health


# This maybe shouldn't be here, also is not currently used
func _get_surface_type() -> Array:
	var cell_index = GameManager.game.level.world_data.get_cell_index_from_local_position(transform.origin)
	var floor_type = GameManager.game.level.world_data.get_cell_surfacetype(cell_index)
	
	match floor_type:
		
		SurfaceType.WOOD:
			return _audio_player._wood_footstep_sounds
	
		SurfaceType.CARPET:
			return _audio_player._carpet_footstep_sounds
	
		SurfaceType.STONE:
			return _audio_player._stone_footstep_sounds
	
		SurfaceType.WATER:
			return _audio_player._water_footstep_sounds
	
		SurfaceType.GRAVEL:
			return _audio_player._gravel_footstep_sounds
	
		SurfaceType.METAL:
			return _audio_player._metal_footstep_sounds
	
		SurfaceType.TILE:
			return _audio_player._tile_footstep_sounds
	
	return _audio_player._footstep_sounds


func _walk(delta, speed_mod : float = 1.0) -> void:
	move_dir = state.move_direction
	move_dir = move_dir.rotated(Vector3.UP, rotation.y)
	
	if do_sprint and stamina > 0 and is_reloading == false and is_moving_forward:
		if is_crouching:
			if can_stand:
				is_crouching = false
				wanna_stand = true
				movement_state = MovementState.STATE_WALKING
			else:
				return
		
		# Sprint speed is walk speed plus stamina * a number, so player slows down as runs longer
		move_dir *= (1.2 + ((stamina / 500) * 0.3))
		change_stamina(-0.3)
		# Additionally, if encumbered, drain stamina more
		if inventory.encumbrance > 0:
#			print("Draining additional stamina: ", (inventory.encumbrance / 10))
			change_stamina(-(inventory.encumbrance / 10))
	else:
		do_sprint = false
		move_dir *= 0.8
		if !do_sprint:
			change_stamina(0.3)
	
	var y_velo = velocity.y
	
	var v1 = 0.5 * move_dir - velocity * Vector3(move_drag, 0, move_drag)
	var v2 
	
	if is_jumping and do_sprint and velocity.y > (jump_force - 1.0):
		v2 = Vector3.DOWN * (gravity * 0.85) * delta
	else:
		v2 = Vector3.DOWN * gravity * delta
	
	velocity += v1 + v2
	
	grounded = is_on_floor() or _ground_checker.is_colliding()
	
	if is_crouching and is_jumping:
		move_and_slide()
	#velocity = move_and_slide((velocity) + get_platform_velocity(),
			#Vector3.UP, true, 4, PI / 4, true)
	else:
		velocity *= speed_mod
		move_and_slide()
		#velocity = move_and_slide((velocity * speed_mod) + get_platform_velocity(),
				#Vector3.UP, true, 4, PI / 4, true)
	
	if move_dir == Vector3.ZERO:
		is_player_moving = false
		self.emit_signal("is_moving", is_player_moving)
	else:
		is_player_moving = true
		self.emit_signal("is_moving", is_player_moving)
	
	if is_on_floor() and is_jumping:   # previously had: and _camera.stress < 0.1
		self.emit_signal("player_landed")
		_audio_player.play_land_sound()
		_camera.add_stress(0.25)
	
	grounded = is_on_floor()   # necessary for this to be here as well as a few lines higher?
	
	if !grounded and y_velo < velocity.y:
			velocity.y = y_velo
	
	if grounded:
		velocity.y -= 0.01
		is_jumping = false
	
	if is_clambering:
		return
	
	if do_jump:
		if is_crouching:
			pass
		elif movement_state != MovementState.STATE_WALKING:
			return
	
		#var c = _clamber_m.attempt_clamber(is_crouching, is_jumping)
		#if c != Vector3.ZERO:
			#if is_clamberable:
				#clamberable_obj = is_clamberable
				#if clamberable_obj is RigidBody3D:   # To allow static objects
					#clamberable_obj.mode = 1
			#clamber_destination = c
			#state = State.STATE_CLAMBERING_RISE
			#is_clambering = true
			#_audio_player.play_clamber_sound(true)
			#do_jump = false
			#return
		
		if is_jumping or !grounded:
			do_jump = false
			return
		
		# Calculate jump force based on sprinting status
		var jump_multiplier = 1.0  # Default jump force multiplier
		if do_sprint and stamina > 0:  # Check if sprinting and have enough stamina
			jump_multiplier = 1.1  # Adjust the multiplier as needed for the desired jump distance
		
		# Apply jump force with the calculated multiplier
		velocity.y = jump_force * jump_multiplier
		
		# TODO: fix being able to "sprint" in air after non-sprinting jump
		
		if do_sprint:
			velocity.x += move_dir.x * jump_force * 1.1
			velocity.z += move_dir.z * jump_force * 1.1
		
		is_jumping = true
		do_jump = false
		
		# Jumping takes stamina, more if you're encumbered
		change_stamina(-30)
		if inventory.encumbrance > 0:
			print("Draining additional stamina on jump: ", (inventory.encumbrance * 10))
			change_stamina(-(inventory.encumbrance * 10))
		
		return
	
	do_jump = false
	
	# Movement audio
	if velocity.length() > 0.1 and grounded and not _audio_player.movement_audio.playing and is_to_move:
		if is_crouching:
			_audio_player.play_footstep_sound(-1.0, 0.1, -20)
		elif do_sprint and is_moving_forward:
			_audio_player.play_footstep_sound(5.0, 1.5)
		else:
			_audio_player.play_footstep_sound(5.0, 1.0)


func _crouch(delta : float) -> void:
	wanna_stand = false
	
	if !_collider.disabled:
		_crouch_collider.set_deferred("disabled", false)
		_collider.set_deferred("disabled", true)
	
#	var from = mainhand_equipment_root.transform.origin.y
#	mainhand_equipment_root.transform.origin.y = lerp(from, crouch_equipment_target_pos, 0.08)
#
#	from = offhand_equipment_root.transform.origin.y
#	offhand_equipment_root.transform.origin.y = lerp(from, crouch_equipment_target_pos, 0.08)
	
	if !grounded and !is_jumping:
		velocity.y -= 5 * (gravity * delta)
	else:
		velocity.y -= 0.05
	
	if is_player_crouch_toggle:
		return
	
	if do_sprint or (!do_crouch and movement_state == MovementState.STATE_CROUCHING):
		if can_stand:
			movement_state = MovementState.STATE_WALKING
			wanna_stand = true
			return


# Move this to a character_anims.gd attached to AnimationPlayer
func check_state_animation(delta):
	var forwards_velocity
	var sideways_velocity
	#if the character is moving sets the velocity to it's movement blendspace2D to create a strafing effect
	
	forwards_velocity = -global_transform.basis.z.dot(velocity)
	sideways_velocity = global_transform.basis.x.dot(velocity)
	
	# This code checks the current item equipped by the player and updates the current_mainhand_item_animation to correspond to it 
	if "Cultist" in self.name:   # Obviously this is a hack, just for the demo and needs to be generalized.
		if current_mainhand_item_animation == HoldStates.MELEE_ITEM:
			
			if movement_state == MovementState.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current", 1)
				animation_tree.set("parameters/Normal_state/current", 4)
				
			if move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current", 1)
				animation_tree.set("parameters/Normal_state/current", 0)
				
			elif move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING :
				animation_tree.set("parameters/Equipped_state/current", 1)
				animation_tree.set("parameters/Normal_state/current", 4)
				
			elif not move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current", 1)
				animation_tree.set("parameters/Normal_state/current", 1)
				animation_tree.set("parameters/walk_strafe/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current", 1)
				animation_tree.set("parameters/Normal_state/current", 5)
				animation_tree.set("parameters/crouch_strafe/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and do_sprint == true:
				animation_tree.set("parameters/Equipped_state/current", 1)
				animation_tree.set("parameters/Normal_state/current", 2)
				
		elif current_mainhand_item_animation == HoldStates.SMALL_GUN_ITEM:
			
			if movement_state == MovementState.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 2)
				animation_tree.set("parameters/Gun_transition/current", 0)
				animation_tree.set("parameters/Small_guns_transitions/current", 4)
				
			if move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 2)
				animation_tree.set("parameters/Gun_transition/current", 0)
				animation_tree.set("parameters/Small_guns_transitions/current", 0)
				
			elif move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING :
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 2)
				animation_tree.set("parameters/Gun_transition/current", 0)
				animation_tree.set("parameters/Small_guns_transitions/current", 4)
				
			elif not move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 2)
				animation_tree.set("parameters/Gun_transition/current", 0)
				animation_tree.set("parameters/Small_guns_transitions/current", 1)
				animation_tree.set("parameters/Pistol_strafe/blend_amount", 1)
				animation_tree.set("parameters/Pistol_strafe_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 2)
				animation_tree.set("parameters/Gun_transition/current", 0)
				animation_tree.set("parameters/Small_guns_transitions/current", 3)
				animation_tree.set("parameters/Pistol_crouch_strafe/blend_amount", 1)
				animation_tree.set("parameters/Pistol_crouch_strafe_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and do_sprint == true:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current",2 )
				animation_tree.set("parameters/Gun_transition/current", 0)
				animation_tree.set("parameters/Small_guns_transitions/current", 2)
				animation_tree.set("parameters/small_gun_run_blend/blend_amount", 1)

		elif current_mainhand_item_animation == HoldStates.LARGE_GUN_ITEM:
			 
			if inventory.get_mainhand_item() and inventory.get_mainhand_item().item_name == "Double-barrel shotgun":
				if movement_state == MovementState.STATE_CROUCHING:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 2)
					animation_tree.set("parameters/ShotgunTransitions/current", 4)
					
				if move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 2)
					animation_tree.set("parameters/ShotgunTransitions/current", 0)
					
				elif move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING :
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 2)
					animation_tree.set("parameters/ShotgunTransitions/current", 4)
					
				elif not move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 2)
					animation_tree.set("parameters/ShotgunTransitions/current", 1)
					animation_tree.set("parameters/ShotgunStrafe/blend_amount", 1)
					animation_tree.set("parameters/ShotgunStrafe/blend_position", Vector2(sideways_velocity, forwards_velocity))
					
				elif not move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 2)
					animation_tree.set("parameters/ShotgunTransitions/current", 3)
					animation_tree.set("parameters/ShotgunCrouchStrafe/blend_amount", 1)
					animation_tree.set("parameters/ShotgunCrouchStrafe/blend_position", Vector2(sideways_velocity, forwards_velocity))
					
				elif not move_dir == Vector3.ZERO and do_sprint == true:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 2)
					animation_tree.set("parameters/ShotgunTransitions/current", 2)
					animation_tree.set("parameters/ShotgunStrafe/blend_amount", 1)
			else:
					
				if movement_state == MovementState.STATE_CROUCHING:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 1)
					animation_tree.set("parameters/Big_guns_transition/current", 4)
					
				if move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 1)
					animation_tree.set("parameters/Big_guns_transition/current", 0)
					
				elif move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING :
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 1)
					animation_tree.set("parameters/Big_guns_transition/current", 4)
					
				elif not move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 1)
					animation_tree.set("parameters/Big_guns_transition/current", 1)
					animation_tree.set("parameters/Rifle_Strafe/blend_amount", 1)
					animation_tree.set("parameters/Rifle_strafe_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
					
				elif not move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 1)
					animation_tree.set("parameters/Big_guns_transition/current", 3)
					animation_tree.set("parameters/Rifle_crouch/blend_amount", 1)
					animation_tree.set("parameters/Crouch_Rifle_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
					
				elif not move_dir == Vector3.ZERO and do_sprint == true:
					animation_tree.set("parameters/Equipped_state/current", 0)
					animation_tree.set("parameters/ADS_State/current", 2)
					animation_tree.set("parameters/Gun_transition/current", 1)
					animation_tree.set("parameters/Big_guns_transition/current", 2)
					animation_tree.set("parameters/Rifle_gun_run_blend/blend_amount", 1)
					
		elif current_mainhand_item_animation == HoldStates.LARGE_GUNS_ADS:
			
			if movement_state == MovementState.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 0)
				animation_tree.set("parameters/ADS_Rifle_state/current", 4)
				
			if move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 0)
				animation_tree.set("parameters/ADS_Rifle_state/current", 0)
				
			elif move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING :
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 0)
				animation_tree.set("parameters/ADS_Rifle_state/current", 4)
				
			elif not move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 0)
				animation_tree.set("parameters/ADS_Rifle_state/current", 1)
				animation_tree.set("parameters/Rifle_ADS_strafe/blend_amount", 1)
				animation_tree.set("parameters/Rifle_ADS_strafe_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 0)
				animation_tree.set("parameters/ADS_Rifle_state/current", 3)
				animation_tree.set("parameters/Rifle_ADS_crouch/blend_amount", 1)
				animation_tree.set("parameters/Rifle_ADS_crouch_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and do_sprint == true:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 0)
				animation_tree.set("parameters/ADS_Rifle_state/current", 2)
				animation_tree.set("parameters/ADS_Rifle_Run/blend_amount", 1)
				
		elif current_mainhand_item_animation == HoldStates.SMALL_GUN_ADS:
			
			if movement_state == MovementState.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 1)
				animation_tree.set("parameters/ADS_Pistol_state/current", 4)
				
			if move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 1)
				animation_tree.set("parameters/ADS_Pistol_state/current", 0)
				
			elif move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING :
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 1)
				animation_tree.set("parameters/ADS_Pistol_state/current", 4)
				
			elif not move_dir == Vector3.ZERO and !movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 1)
				animation_tree.set("parameters/ADS_Pistol_state/current", 1)
				animation_tree.set("parameters/One_Handed_ADS_Strafe/blend_amount", 1)
				animation_tree.set("parameters/One_Handed_ADS_Strafe_Vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and movement_state == MovementState.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 1)
				animation_tree.set("parameters/ADS_Pistol_state/current", 3)
				animation_tree.set("parameters/One_Handed_ADS_Crouch/blend_amount", 1)
				animation_tree.set("parameters/One_Handed_ADS_Crouch_Vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and do_sprint == true:
				animation_tree.set("parameters/Equipped_state/current", 0)
				animation_tree.set("parameters/ADS_State/current", 1)
				animation_tree.set("parameters/ADS_Pistol_state/current", 2)
				animation_tree.set("parameters/One_Handed_ADS_Run/blend_amount", 1)

# Checks if the character is on the ground if not plays the falling animation
	if !grounded and !_ground_checker.is_colliding():
		animation_tree.set("parameters/Falling/active",true)
	else:
		animation_tree.set("parameters/Falling/active",false)


func check_current_item_animation():
		# This code checks the current item type the player is equipping and set the animation that matches that item in the animation tree
		var mainhand_object = inventory.current_mainhand_slot
		var offhand_object = inventory.current_offhand_slot
		
		# temporary hack (issue #409) - not sure it's necessary
		if not is_instance_valid(inventory.hotbar[mainhand_object]):
			inventory.hotbar[mainhand_object] = null
		
		if inventory.hotbar[mainhand_object] is GunItem:
			if inventory.hotbar[mainhand_object].item_size == 0:
				current_mainhand_item_animation = HoldStates.SMALL_GUN_ITEM
			else:
				current_mainhand_item_animation = HoldStates.LARGE_GUN_ITEM
#		elif inventory.hotbar[main_hand_object] is LanternItem or inventory.hotbar[off_hand_object] is LanternItem:
#			print("Carried Lantern")
			#update this to work for items animations
		elif inventory.hotbar[mainhand_object] is MeleeItem:
			current_mainhand_item_animation = HoldStates.MELEE_ITEM



func change_stamina(amount: float) -> void:
	stamina = min(600, max(0, stamina + amount))


func _on_ClamberableChecker_body_entered(body):
	if body.is_in_group("CLAMBERABLE"):
		is_clamberable = body
#
#	if event.is_action_pressed("player|crouch"):
#		if $crouch_timer.is_stopped(): # && !$AnimationTree.get(roll_active):
#			$crouch_timer.start()
#			$AnimationTree.tree_root.get_node("cs_transition").xfade_time = (velocity.length() + 1.5)/ 15.0
#			crouch_stand_target = 1 - crouch_stand_target
#			$AnimationTree.set(cs_transition, crouch_stand_target)


func move_effect():
	# Plays the belt bobbing animation if the player is moving 
	if velocity != Vector3.ZERO:
		additional_animations.play("Belt_bob", -1, velocity.length() / 2)


func _on_Inventory_mainhand_slot_changed(previous, current):
	# Checks if there is something currently equipped, else does nothing
	if inventory.hotbar[current] != null :
		pass
	else:
		current_mainhand_item_animation = HoldStates.MELEE_ITEM
		mainhand_animation = AnimationState.NOT_EQUIPPED
