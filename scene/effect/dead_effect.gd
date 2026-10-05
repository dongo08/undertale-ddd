extends Node2D
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
@onready var gpu_particles_2d_2: GPUParticles2D = $GPUParticles2D2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gpu_particles_2d.emitting=true
	gpu_particles_2d_2.emitting=true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	$Ball16.modulate*=0.5
