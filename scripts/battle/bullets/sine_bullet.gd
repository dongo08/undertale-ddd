extends BaseBullet
class_name SineBullet

@export var amplitude: float = 200.0
@export var center_x:float=320
@export var period:float=5
@export var speed: float = 200.0
@export var move_right: bool = true

var _elapsed: float = 0.0
var _phase: float

func _ready() -> void:
	var raw := asin(clampf((position.x - center_x) / amplitude, -1.0, 1.0))
	_phase = raw if move_right else PI - raw

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# 物理帧驱动（原来在 _process 里，渲染帧驱动没法复现）
	_elapsed += delta
	var freq := TAU / period
	position.x = center_x + amplitude * sin(freq * _elapsed + _phase)
	position.y += speed * delta
