extends BattleManager


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !BGM.is_playing():
		BGM.play(preload("uid://chntm3oqxwyhy"),0,0)
	super._ready()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
