extends Node2D
class_name BaseEnemyTurnManager
const BASE_BULLET = preload("uid://dc41q0lfey1qr")
const EXPLODE_EFFECT = preload("uid://djpv4bs5mo5ui")
const SE_TAN_00 = preload("uid://oie1o8543ko7")
const 弹幕嗡声 = preload("uid://xuishfumuwcu")
const SE_TAN_02 = preload("uid://bhbpd23lvqvvc")

@export var master: BattleManager
var bullets: Array[BaseBullet]
var polygon_tween: Tween
## 战斗框过渡的代次号（同上：有更新的过渡时让位）
var _polygon_trans_id: int = 0

var lu: Vector2
var ru: Vector2
var rd: Vector2
var ld: Vector2

signal finished(mgr:BaseEnemyTurnManager)

var _self_player:AudioStreamPlayer


# ── 生命周期 ──

func _ready() -> void:
	_self_player=AudioStreamPlayer.new()
	_self_player.bus="Sounds"
	add_child(_self_player)
	z_index=10

func start():
	_init_corners()
	

func end():
	finished.emit(self)
	#queue_free()


# ── 快捷方法 ──

func wait(t: float):
	# 按物理帧等（tick 驱动，回放才能逐帧重现）
	await BattleClock.wait_seconds(t)


## 按物理帧把一个数值属性平滑插值（线性，跟 tween 默认的 TRANS_LINEAR 一致）。
## gameplay 用的数值不能用 tween 驱动：tween 的起点会落在两个物理帧之间，
## 实测两次同样输入的运行会差出 0.6 tick，弹幕就对不上了。
func ramp_property(property: StringName, from: float, to: float, seconds: float) -> void:
	var ticks := BattleClock.seconds_to_ticks(seconds)
	if ticks <= 0:
		set(property, to)
		return
	var step := (to - from) / float(ticks)
	var value := from
	for i in ticks:
		value += step
		set(property, value)
		await get_tree().physics_frame
	set(property, to)

func get_soul_pos() -> Vector2:
	return master.soul.global_position

func get_frame_center() -> Vector2:
	return (lu + rd) / 2.0

func get_frame_rect() -> Dictionary:
	return {"left": lu.x, "right": ru.x, "top": lu.y, "bottom": ld.y}

func _init_corners():
	var p = get_battleframe_polygon()
	lu = p[0]
	ru = p[1]
	rd = p[2]
	ld = p[3]


# ── 灵魂控制 ──

func move_soul(pos: Vector2):
	if master.soul:
		master.soul.position = pos

func set_soul_mode(mode: Soul.Type):
	master.soul.type = mode

func set_soul_gravity(dir: Soul.GDir):
	master.soul.g_dir = dir

func lock_soul(locked: bool):
	master.soul.movement_locked = locked


# ── 子弹生成 ──

func spawn_base_bullet(pos: Vector2, direction: Vector2, speed: float = 300,lifetime:float=16):
	var bullet = BASE_BULLET.instantiate() as NormalBullet
	bullet.position = pos
	bullet.manager=self
	bullet.direction=direction
	bullet.speed=speed
	bullet.lifetime=lifetime
	
	add_child(bullet)
	
	bullets.append(bullet)
	return bullet




func spawn_bullet_fan(origin: Vector2, dir: Vector2, spread: float, count: int, speed: float = 300):
	for i in range(count):
		var angle = dir.rotated((i - (count - 1) / 2.0) * spread / float(count - 1))
		spawn_base_bullet(origin, angle, speed)

func spawn_bullet_circle(center: Vector2, count: int, speed: float = 300, bscale:Vector2=Vector2.ONE, offset_angle: float = 0.0,change_rotate:bool=true):
	var step = TAU / count
	for i in range(count):
		var dir = Vector2.RIGHT.rotated(i * step + offset_angle)
		var a=spawn_base_bullet(center, dir, speed)
		if change_rotate:
			a.rotation=i * step + offset_angle-PI/2
		a.scale=bscale


# ── 战斗框 ──

func direction_to_soul(pos: Vector2) -> Vector2:
	return master.direction_to_soul(pos)

func get_battleframe_polygon() -> PackedVector2Array:
	return master.battle_frame_border.collision.polygon

func set_battleframe_polygon(polygon: PackedVector2Array):
	master.set_battleframe_polygon(polygon)

func set_battleframe_polygon_trans(
	polygon: PackedVector2Array = [Vector2(100, 260), Vector2(540, 260), Vector2(540, 440), Vector2(100, 440)],
	duration: float = 0.8
):
	if polygon_tween and polygon_tween.is_running():
		polygon_tween.kill()
	# 碰撞多边形是 gameplay（灵魂会撞它），逐 tick 插值，不能由 tween 驱动
	_polygon_trans_id += 1
	var my_id := _polygon_trans_id
	var from = get_battleframe_polygon()
	var ticks := BattleClock.seconds_to_ticks(duration)
	for i in ticks:
		if _polygon_trans_id != my_id:
			return
		var t := float(i + 1) / float(ticks)
		var eased := 1.0 - pow(1.0 - t, 2.0)
		if from.size() == polygon.size():
			var points := PackedVector2Array()
			for k in from.size():
				points.append(from[k].lerp(polygon[k], eased))
			set_battleframe_polygon(points)
		await get_tree().physics_frame
	set_battleframe_polygon(polygon)

func play_sound(stream: AudioStream, from_offset: float = 0, volume_db: float = 0, pitch_scale: float = 1.0):
	master.play_bullet_sound(stream,from_offset,volume_db,pitch_scale)

func self_play_sound(stream: AudioStream, from_offset: float = 0, volume_db: float = 0, pitch_scale: float = 1.0):
	_self_player.stream=stream
	_self_player.volume_db=volume_db
	_self_player.pitch_scale=pitch_scale
	_self_player.play(from_offset)

func create_explode_effect(pos:Vector2 ,explode_scale:Vector2=Vector2.ONE):
	var ex=EXPLODE_EFFECT.instantiate() as Node2D
	ex.scale=explode_scale
	ex.position=pos
	add_child(ex)

func create_physics_tween()->Tween:
	return create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
