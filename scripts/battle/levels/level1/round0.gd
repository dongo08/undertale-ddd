extends Level1EnemyTurnManager
var sin_speed:float=120

## sin_speed 的关键帧（秒, 目标值）。原来这段是 tween 驱动的，
## 但 tween 的起点会落在两个物理帧之间（实测同输入两次运行差 0.6 tick），
## 所以自己按 tick 插值 —— 回放才能长出一样的弹幕。
const SIN_SPEED_KEYS: Array = [[0.5, 200.0], [1.5, 50.0], [1.2, 200.0], [1.0, 60.0]]
var _speed_elapsed: float = 0.0
var _speed_running: bool = false


func _physics_process(delta: float) -> void:
	if not _speed_running:
		return
	_speed_elapsed += delta
	sin_speed = _sin_speed_at(_speed_elapsed)


## 逐段 ease-in-out 正弦（和原来 tween 的 TRANS_SINE / EASE_IN_OUT 一致）
func _sin_speed_at(t: float) -> float:
	var from := 120.0
	var acc := 0.0
	for step in SIN_SPEED_KEYS:
		var duration: float = step[0]
		var to: float = step[1]
		if t < acc + duration:
			var local := (t - acc) / duration
			return from + (to - from) * (0.5 - 0.5 * cos(PI * local))
		acc += duration
		from = to
	return from


func start():
	
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(200, 260), Vector2(440, 260), Vector2(440, 440), Vector2(200, 440)])
	await wait(1)
	generate_sine_bullet()
	generate_circle_bullet()
	
	
	
func generate_sine_bullet():
	_speed_elapsed = 0.0
	_speed_running = true
	var emit_pos=Vector2(340,30)
	for i in range(40):
		spawn_sin_bullet(emit_pos,sin_speed,false,Vector2.ONE,5.5)
		spawn_sin_bullet(Vector2(300,30),sin_speed+20,true,Vector2.ONE,5.4)
		await BattleClock.wait_seconds(0.1)
	_speed_running = false
	await BattleClock.wait_seconds(3)
	end()
func generate_circle_bullet():
	await wait(1)
	var pos=Vector2(320,150)
	var bullet_interval=TAU/8
	for i in range(2):
		var speed:float=100
		var a:int=-1 if i==0 else 1
		var ro:float=bullet_interval/4*(i+1)
		for j in range(6):
			for k in range(8):
				spawn_base_bullet(pos,Vector2.RIGHT.rotated(ro+bullet_interval*k),speed)
			play_sound(SE_TAN_00)
			speed+=100
			ro+=bullet_interval/6*a
			await wait(0.166)
		await wait(1)
		
