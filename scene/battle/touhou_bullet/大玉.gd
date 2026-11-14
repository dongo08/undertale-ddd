extends NormalBullet
@onready var sprite_2d: Sprite2D = $Sprite2D2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	sprite_2d.rotate(PI*8*delta)

func destroy_animate():
	var tween=create_tween()
	tween.tween_property(sprite_2d,"scale",Vector2(0,0),0.3)
	await BattleClock.wait_seconds(0.3)
