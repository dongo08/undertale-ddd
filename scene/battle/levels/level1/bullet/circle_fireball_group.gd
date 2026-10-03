extends Node2D

const BASE_BULLET = preload("uid://dc41q0lfey1qr")
const CIRCLE_FIREBALL_SINGLE = preload("uid://em5i4ot7wcyi")

@export var amount:int=4
@export var center:Vector2=Vector2(320,360)
@export var distance:float=120
@export var rotate_duration:float=2.6
@export var rotate_v:float=3
@export var anti:bool
@export var explode_duration:float=3.1
var bullets:Array[BaseBullet]
var interval:float
var ball_tween:Tween
var alpha_tween:Tween
signal explode(pos:Vector2,rad:float)

func _ready() -> void:
	interval=TAU/amount
	rotation=BattleRNG.randf()*TAU
	position=center
	alpha_tween=create_tween()
	alpha_tween.tween_property(self,"modulate:a",1,1).from(0)
	for i in range(amount):
		var bullet=CIRCLE_FIREBALL_SINGLE.instantiate() as BaseBullet
		bullet.position=Vector2.UP.rotated(interval*i)*distance
		bullet.rotation=interval*i
		bullets.append(bullet)
		add_child(bullet)
	await BattleClock.wait_seconds(explode_duration)
	# 收束动画只是画面；爆炸信号和回收按 tick 走，不然子弹消失的时机也会漂
	ball_tween=create_tween()
	for i in bullets:
		ball_tween.parallel().tween_property(i,"position",Vector2.ZERO,0.3)
	await BattleClock.wait_seconds(0.3)
	explode.emit(position, rotation)
	queue_free()
	

func _physics_process(delta: float) -> void:
	rotate_duration-=delta
	if rotate_duration<0:
		return
	if anti:
		rotate(-rotate_v*delta)
	else:
		rotate(rotate_v*delta)
