extends Node2D

func _ready() -> void:
	$GPUParticles2D.emitting=true
	await get_tree().create_timer(0.5).timeout
	queue_free()
