extends Node2D
class_name AttackBar
@export var dumb_target: Sprite2D 
@export var attack_cursor: AttackCursor
@export var attack_effect: AnimatedSprite2D
@export var dmg_miss: Sprite2D 
@export var master:BattleManager
@onready var snd_laz: AudioStreamPlayer = $SndLaz
@onready var snd_damage: AudioStreamPlayer = $SndDamage
@export var damage_label: Label
@export var hp_bar: TextureProgressBar 

## 血条 / 伤害数字 / 攻击特效 / 未命中标记相对“被攻击立绘中心”的偏移
## （没给这个敌人登记立绘时，就保持场景里摆好的原位置不动）
@export var hp_bar_center_offset:Vector2=Vector2(0,16)
@export var damage_label_center_offset:Vector2=Vector2(0,-23)
@export var attack_effect_center_offset:Vector2=Vector2(0,-18)
@export var dmg_miss_center_offset:Vector2=Vector2(0,-2)

var bar_tween:Tween
var enemy_index:int
var coverage_damage:float=-1
signal attack_done()
## 哪个敌人被打死了（多敌人时要知道死的是谁）
signal enemy_dead(index:int)
func _ready() -> void:
	dumb_target.hide()
	attack_cursor.hide()
	attack_effect.hide()
	dmg_miss.hide()
	hp_bar.hide()
	damage_label.hide()
	set_process_input(false)
	attack_cursor.attack.connect(attack_cursor_effect)
	attack_cursor.miss.connect(attack_cursor_miss)
	
func attack(index:int=0,coverage:float=-1):
	dumb_target.show()
	attack_cursor.start()
	enemy_index=index
	coverage_damage=coverage
	_aim_feedback_at_enemy()
	await get_tree().process_frame
	set_process_input(true)


## 把血条、伤害数字、攻击特效挪到被攻击的那个敌人的立绘上
func _aim_feedback_at_enemy()->void:
	if master==null:
		return
	var portrait:=master.portrait_for_enemy(enemy_index)
	if portrait==null:
		return
	var center:=portrait.global_position
	_place_control_center(hp_bar,center+hp_bar_center_offset)
	_place_control_center(damage_label,center+damage_label_center_offset)
	if attack_effect:
		attack_effect.global_position=center+attack_effect_center_offset
	if dmg_miss:
		dmg_miss.global_position=center+dmg_miss_center_offset

static func _place_control_center(control:Control,center:Vector2)->void:
	if control==null:
		return
	control.global_position=center-control.size*0.5

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("accept"):
		attack_cursor.effect()
		
func attack_cursor_effect(factor:float,best:bool):
	set_process_input(false)
	attack_effect.show()
	attack_effect.play("default")
	snd_laz.play()
	await attack_effect.animation_finished
	attack_effect.hide()
	#await get_tree().create_timer(0.2).timeout
	
	if master.battle_data.enemys[enemy_index].invincible:
		dmg_miss.show()
	else:
		if bar_tween and bar_tween.is_running():
			bar_tween.kill()
		bar_tween=create_tween()
		var hp=master.battle_data.enemys[enemy_index].hp
		var max_hp=master.battle_data.enemys[enemy_index].max_hp
		var def=master.battle_data.enemys[enemy_index].defense
		hp_bar.max_value=max_hp
		hp_bar.value=hp
		var real:float
		var atk:float
		if is_equal_approx(coverage_damage,-1):
			atk=master.battle_data.player_status.attack
			real=_calculate_damage(atk,factor,hp,max_hp,best,def)
		else:
			real=coverage_damage
		master.battle_data.enemys[enemy_index].hp-=real
		damage_label.text=String.num(real,0)
		hp_bar.show()
		damage_label.show() 
		bar_tween.tween_property(hp_bar,'value',master.battle_data.enemys[enemy_index].hp,0.5)
		bar_tween.tween_callback(func():hp_bar.hide();damage_label.hide()).set_delay(0.3)
		snd_damage.play()
		if master.battle_data.enemys[enemy_index].hp<=0:
			enemy_dead.emit(enemy_index)
	await get_tree().create_timer(0.8).timeout
	end()
	dmg_miss.hide()
func attack_cursor_miss():
	set_process_input(false)
	dmg_miss.show()
	
	end()
	await get_tree().create_timer(0.8).timeout
	dmg_miss.hide()

func end():
	dumb_target.hide()
	attack_cursor.hide()
	attack_effect.hide()
	# 打死的那个敌人已经不算数了：还有活着的敌人就继续本回合，全死了就交给 enemy_dead 的死亡流程
	if not master.has_living_enemy():
		return
	attack_done.emit()

static func _calculate_damage(atk:float,factor:float,hp:float,max_hp:float,best:bool=false,def:float=0)->float:
	return max(0,atk*factor-def*(hp/max_hp)+randf_range(-atk*0.05,+atk*0.05))+(atk*0.1 if best else 0)
