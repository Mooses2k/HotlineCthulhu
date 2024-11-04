class_name BTRoot extends BTSequence


signal pre_tick()
signal post_tick()

var tick_delta : float = 0.1

func _ready() -> void:
	super._ready()
	_setup_ai_tree()
	#var timer := Timer.new()
	#timer.one_shot = false
	#timer.wait_time = tick_delta
	#timer.timeout.connect(run_tick)
	#add_child(timer)
	#timer.start()


func run_tick(state : CharacterState):
	emit_signal("pre_tick")
	tick(state)
	emit_signal("post_tick")



func _setup_ai_tree() -> void:
	_setup_node(self)


func _setup_node(node : BTNode) -> void:
	pre_tick.connect(node.on_pre_tick)
	post_tick.connect(node.on_post_tick)
	node._root = self
	for child in node.get_children():
		if child is BTNode:
			_setup_node(child)


# Delete mind, cancelling further planning and speech.
func _on_character_died() -> void:
	queue_free()
