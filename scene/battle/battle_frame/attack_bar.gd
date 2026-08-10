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

var bar_tween:Tween
var enemy_index:int
var coverage_damage:float=-1
signal attack_done()
signal enemy_dead()
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
	await get_tree().process_frame
	set_process_input(true)

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
			enemy_dead.emit()
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
	if master.battle_data.enemys[enemy_index].hp<=0:
		return
	attack_done.emit()

static func _calculate_damage(atk:float,factor:float,hp:float,max_hp:float,best:bool=false,def:float=0)->float:
	return max(0,atk*factor-def*(hp/max_hp)+randf_range(-atk*0.05,+atk*0.05))+(atk*0.1 if best else 0)
