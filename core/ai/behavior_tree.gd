class_name BehaviorTree
extends Node


export var bt_root : NodePath

onready var _bt_root_node = get_node(bt_root) as BT_Node
onready var character = owner


func _physics_process(delta):
	_bt_root_node.tick(character.character_state)


func _on_character_died():
	self.queue_free()   # Delete mind, cancelling further planning and speech
