extends Control
const MUS_GAMEOVER = preload("uid://d1uhy1lghwmwv")
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	BGM.play(MUS_GAMEOVER,0,0)
	animation_player.play("new_animation")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("accept"):
		BGM.stop(2)
		Global.change_scene_to_packed(load("uid://p40nr6suok34"),2,Color.BLACK)
