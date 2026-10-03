extends BaseBullet
var center_pos:Vector2=Vector2(320,360)
var strength:bool
var is_up:bool
var duration:float=2
var next_pos:Vector2

## 轨迹状态：原来整条轨迹是 tween 驱动的，但 tween 的起点会落在两个物理帧之间
## （实测同输入两次运行会差出亚 tick 的量），所以改成按 tick 自己算。
var _x_from:float
var _x_to:float
var _y_dist:float
var _elapsed:float=0.0

func _ready() -> void:
	var x_dist:float
	var y_dist:float
	if is_up:
		x_dist=220
		if strength:
			y_dist=100
		else:
			y_dist=140
			duration=1.8
	else:
		x_dist=-220
		if strength:
			y_dist=-100
		else:
			y_dist=-140
			duration=1.8
	position=Vector2(center_pos.x+x_dist,center_pos.y)
	_x_from=center_pos.x-x_dist
	_x_to=center_pos.x+x_dist
	_y_dist=y_dist
	next_pos=Vector2(_x_from,center_pos.y)

func _physics_process(delta: float) -> void:
	var previous:=position
	_elapsed=minf(_elapsed+delta,duration)
	var half:=duration/2.0
	next_pos.x=lerpf(_x_from,_x_to,_elapsed/duration)
	# y 先走半程（sine EASE_OUT）再回半程（sine EASE_IN），跟原来两段 tween 一致
	if _elapsed<=half:
		next_pos.y=center_pos.y+_y_dist*sin((_elapsed/half)*PI/2.0)
	else:
		next_pos.y=center_pos.y+_y_dist*cos(((_elapsed-half)/half)*PI/2.0)
	rotation=(next_pos-previous).angle()-PI/2
	position=next_pos
	if _elapsed>=duration:
		queue_free()
