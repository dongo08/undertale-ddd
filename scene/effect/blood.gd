extends Node2D

func _ready() -> void:
	$GPUParticles2D.emitting=true
	await BattleClock.wait_seconds(0.5)
	queue_free()
