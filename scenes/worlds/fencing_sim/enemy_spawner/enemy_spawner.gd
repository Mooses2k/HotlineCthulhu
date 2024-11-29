extends Node3D

@onready var enemy_spawner_timer: Timer = $Timer

@export_subgroup("Scene Behavior")
@export var spawn_time: float

@export_subgroup("Scene Configuration")
@export var candle_manager: CandleCircle
## Wich node to add the enemy as child
@export var spawn_root: Node3D
@export var ENEMY_SCENE: PackedScene


func _ready() -> void:
	randomize()
	enemy_spawner_timer.timeout.connect(_on_spawn_timer_timeount)

## When the timer runs out, pick a random localtion and spawn at it
func _on_spawn_timer_timeount() -> void:
	var positions = candle_manager.get_candles_world_position()
	
	var random_index: int = randi_range(0, positions.size())
	var target_position: Vector3 = positions[random_index]
	
	spawn_enemy(target_position)


func spawn_enemy(spawn_position: Vector3) -> void:
	if ENEMY_SCENE == null:
		push_error("No scene for the enemy instance was defined")
	
	var enemy: Node3D = ENEMY_SCENE.instantiate()
	enemy.global_position = spawn_position
	spawn_root.add_child(enemy)


func start_spawning() -> void:
	enemy_spawner_timer.start()


func stop_spawning() -> void:
	enemy_spawner_timer.stop()
