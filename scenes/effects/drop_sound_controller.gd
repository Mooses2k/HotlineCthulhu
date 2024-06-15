extends AudioStreamPlayer3D


func _enter_tree():
	self.play()


func _on_Spatial_finished():
	prints("Drop sound was played by", self.get_parent(), "at", self.global_position, "with player at", GameManager.game.player.global_position)
	get_parent().remove_child(self)
