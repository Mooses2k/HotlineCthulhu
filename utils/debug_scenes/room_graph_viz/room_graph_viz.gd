# Write your doc string for this file here
class_name RoomGraphViz
extends Node2D

#- Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const COLOR_ROOMS = Color(0.3,0.3,0.3,1.0)
const COLOR_CORRIDORS = Color(0.5,0.3,0.3,1.0)
const COLOR_DOORS = Color(0.3,0.5,0.3,1.0)
const COLOR_HALLS = Color(0.3,0.3,0.5,1.0)
const COLOR_DELAUNAY = Color.CYAN
const COLOR_CONNECTIONS = Color.YELLOW_GREEN
const COLOR_ASTAR = Color.ORANGE_RED

const PATH_FONT = "res://resources/fonts/godot_default_bitmapfont.tres"

#--- public variables - order: export > normal var > onready --------------------------------------

@export var max_minimap_screen_height := 0.5 # (float, 0.1, 1.0, 0.1)
@export var distances_scale := 30.0: set = _set_distances_scale
@export var draw_basic_grid := true: set = _set_draw_basic_grid
@export var draw_map := true: set = _set_draw_map
@export var draw_full_delaunay := true: set = _set_draw_full_delaunay
@export var draw_chosen_connections := true: set = _set_draw_chosen_connections
@export var draw_astar_grid := true: set = _set_draw_astar_grid
@export var draw_astar_connections := true: set = _set_draw_astar_connections
@export var draw_player := true: set = _set_draw_player

var font: Font = null

var world_data: WorldData = null: set = _set_world_data

var room_centers_cell_indexes := PackedInt32Array()
var room_centers := PackedVector2Array(): set = _set_room_centers
var delaunay := PackedInt32Array()
var room_connections := {}: set = _set_room_connections

var astar: ManhattanAStar2D = null

#--- private variables - order: export > normal var > onready -------------------------------------

@onready var _player_icon: Node2D = $PlayerIcon 

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	if is_instance_valid(GameManager.game):
		# warning-ignore:return_value_discarded
		GameManager.game.connect("player_spawned", Callable(self, "_on_game_player_spawned"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("misc|map_menu"):
		visible = !visible


func _draw() -> void:
	if font == null:
		font = load(PATH_FONT)
	
	if world_data != null:
		if draw_basic_grid:
			for cell_index in world_data.cell_count:
				var cell_rect := _get_cell_rect_from_cell_index(cell_index)
				var color = Color.GRAY
				color.a = 0.2
				draw_rect(cell_rect, color, false)
		
		if draw_map:
			var room_cells := world_data.get_cells_for(world_data.CellType.ROOM)
			for cell_index in room_cells:
				var cell_rect := _get_cell_rect_from_cell_index(cell_index)
				draw_rect(cell_rect, COLOR_ROOMS)
			
			var corridor_cells := world_data.get_cells_for(world_data.CellType.CORRIDOR)
			for cell_index in corridor_cells:
				var cell_rect := _get_cell_rect_from_cell_index(cell_index)
				draw_rect(cell_rect, COLOR_CORRIDORS)
			
			var door_cells := world_data.get_cells_for(world_data.CellType.DOOR)
			for cell_index in door_cells:
				var cell_rect := _get_cell_rect_from_cell_index(cell_index)
				draw_rect(cell_rect, COLOR_DOORS)
			
			var hall_cells := world_data.get_cells_for(world_data.CellType.HALL)
			for cell_index in hall_cells:
				var cell_rect := _get_cell_rect_from_cell_index(cell_index)
				draw_rect(cell_rect, COLOR_HALLS)
	
	if astar != null:
		var astar_points := astar.get_point_ids()
		
		for cell_index in astar_points:
			var cell_rect := _get_cell_rect_from_cell_index(cell_index)
			if draw_astar_grid:
				var faded_color := COLOR_ASTAR
				faded_color.a = 0.5
				draw_rect(cell_rect, faded_color, false)
				
				var weight := astar.get_point_weight_scale(cell_index)
				var weight_position := cell_rect.position + Vector2(0, distances_scale / 2.0)
				draw_string(font, weight_position, "%.1f"%[weight], 0, -1, 16, faded_color)
			
			if draw_astar_connections:
				var connections := astar.get_point_connections(cell_index)
				var from_middle_point := cell_rect.position + cell_rect.size / 2.0
				for to_index in connections:
					var to_cell := _get_cell_rect_from_cell_index(to_index)
					var to_middle_point := to_cell.position + to_cell.size / 2.0
					draw_line(from_middle_point, to_middle_point, Color.ORANGE)
	
	if draw_full_delaunay:
		for point in room_centers:
			var cell_rect := Rect2(point, Vector2.ONE * distances_scale)
			draw_rect(cell_rect, COLOR_DELAUNAY, false)
		
		for index in range(0, delaunay.size(), 3):
			var vertice_a := room_centers[delaunay[index]]
			var vertice_b := room_centers[delaunay[index + 1]]
			var vertice_c := room_centers[delaunay[index + 2]]
			
			draw_line(vertice_a, vertice_b, COLOR_DELAUNAY)
			draw_line(vertice_b, vertice_c, COLOR_DELAUNAY)
			draw_line(vertice_c, vertice_a, COLOR_DELAUNAY)
	
	if draw_chosen_connections:
		for cell_index in room_connections:
			var from_index := room_centers_cell_indexes.find(cell_index)
			var from_position := room_centers[from_index]
			for connected_cell_index in room_connections[cell_index]:
				var to_index := room_centers_cell_indexes.find(connected_cell_index)
				var to_position := room_centers[to_index]
				
				draw_line(from_position, to_position, COLOR_CONNECTIONS)

#--------------------------------------------------------------------------------------------------


#- Public Methods --------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Private Methods -------------------------------------------------------------------------------

func _get_cell_rect_from_cell_index(cell_index: int) -> Rect2:
	var positions_array := world_data.get_int_position_from_cell_index(cell_index)
	var value := Rect2(
			Vector2(positions_array[0], positions_array[1]) * distances_scale, 
			Vector2.ONE * distances_scale
	)
	return value


func _set_room_centers(value: PackedVector2Array) -> void:
	room_centers = value
	if not room_centers.is_empty() and is_inside_tree():
		for index in room_centers.size():
			var point := room_centers[index]
			room_centers[index] = point * distances_scale


func _set_room_connections(value: Dictionary) -> void:
	room_connections = value.duplicate(true)
	if not room_connections.is_empty() and is_inside_tree():
		print("room indexes: %s" % [room_centers_cell_indexes])
		print("room_connections: %s" % [room_connections])


func _set_distances_scale(value: float) -> void:
	distances_scale = value
	queue_redraw()


func _set_draw_basic_grid(value: bool) -> void:
	draw_basic_grid = value
	queue_redraw()


func _set_draw_map(value: bool) -> void:
	draw_map = value
	queue_redraw()


func _set_draw_full_delaunay(value: bool) -> void:
	draw_full_delaunay = value
	queue_redraw()


func _set_draw_chosen_connections(value: bool) -> void:
	draw_chosen_connections = value
	queue_redraw()


func _set_draw_astar_grid(value: bool) -> void:
	draw_astar_grid = value
	queue_redraw()


func _set_draw_astar_connections(value: bool) -> void:
	draw_astar_connections = value
	queue_redraw()


func _set_draw_player(value: bool) -> void:
	draw_player = value
	set_process(draw_player)


func _set_world_data(value: WorldData) -> void:
	world_data = value
	var world_size_y := world_data.world_size_z
	var viewport_size := get_viewport_rect().size
	if world_size_y * distances_scale > viewport_size.y * max_minimap_screen_height:
		distances_scale = viewport_size.y * max_minimap_screen_height / world_size_y

#--------------------------------------------------------------------------------------------------


#- Signal Callbacks ------------------------------------------------------------------------------

func _on_world_generation_finished() -> void:
	queue_redraw()


func _on_game_player_spawned(p_player: Player) -> void:
	_player_icon.player = p_player
	hide()   # Hidden by default
	
	if not p_player.is_connected("character_died", Callable(self, "_on_player_character_died")):
		p_player.connect("character_died", Callable(self, "_on_player_character_died"))


func _on_player_character_died() -> void:
	hide()

#--------------------------------------------------------------------------------------------------
