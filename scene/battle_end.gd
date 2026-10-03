extends Control
const FALLEN_DOWN = preload("uid://cmvxrrxxngr20")

func _ready() -> void:
	BGM.play(FALLEN_DOWN,0,0)
	BGM.set_slow(true,0)
	BGM.set_pitch_scale(0.5)
	await BattleClock.wait_seconds(1)
	
