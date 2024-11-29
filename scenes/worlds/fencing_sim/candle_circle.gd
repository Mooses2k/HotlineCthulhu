@tool
## This class is used specificaaly for Fencing Sim, to avoid unwanted behaviors, avoid setting variables directly
class_name CandleCircle
extends Node3D

@export_range(0, 20, 0.1) var diameter: float = 5.0: set = _diameter_setter
@export_range(0, 12, 1) var candle_count: int = 8: set = _candle_count_setter
@export var candle_scene: PackedScene

func _ready() -> void:
	_generate_candles(); # This is called cause the script is a tool script, but for spawning when the game starts, you need to put the logic inside _ready
	
	for candle : CandleItem in get_children():
		candle.light()

func _generate_candles() -> void:
	var radius = diameter / 2.0
	
	# clear children
	for child in get_children():
		child.queue_free()
	
	for i in range(candle_count):
		var theta = 2 * PI * i / candle_count
		var x = radius * cos(theta)
		var z = radius * sin(theta)
		
		var candle_instance = candle_scene.instantiate() as CandleItem
		candle_instance.global_position = Vector3(x, 0, z)
		
		add_child(candle_instance)

## Returns a dictionary containing the index and position of a candle [br]
## Ex of return: {1: Vector3(69, 69, 420) }
func get_candles_world_position() -> Dictionary:
	var positions: Dictionary
	for child_index: int in get_child_count():
		positions[child_index] = get_child(child_index).global_position
	
	return positions
	pass

## Use this method whenever you need to update the circle
func update_circle(new_diameter: float, new_candle_count: int) -> void:
	diameter = new_diameter
	candle_count = new_candle_count

## -------------- SETTERS - Do not call from outside, or do --------

func _diameter_setter(new_diameter: float) -> void:
	print('set diameter')
	diameter = new_diameter
	if is_inside_tree():
		_generate_candles()

func _candle_count_setter(new_count: int) -> void:
	print('set candle count')
	candle_count = new_count
	if is_inside_tree():
		_generate_candles()
