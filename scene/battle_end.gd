extends Control
const FALLEN_DOWN = preload("uid://cmvxrrxxngr20")

func _ready() -> void:
	BGM.play(FALLEN_DOWN,0,0)
	BGM.set_slow(true,0)
	BGM.set_pitch_scale(0.5)
	await get_tree().create_timer(1).timeout
	
