extends Node
const RAND_UPDATE = preload("uid://chkncv4h7lp48")
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		if get_tree().root.mode!=Window.MODE_FULLSCREEN:
			get_tree().root.mode=Window.MODE_FULLSCREEN
		else:
			get_tree().root.mode=Window.MODE_WINDOWED

func create_rand_update_effect(node:Node)->Node:
	var rand_update=RAND_UPDATE.instantiate()
	get_tree().root.add_child(rand_update)
	node.reparent(rand_update.screen_viewport)
	return node
