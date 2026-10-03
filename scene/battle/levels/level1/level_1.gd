extends BattleManager

const CIRCLE_FIREBALL_GROUP = preload("uid://c8a60i6no477r")
const BATTLE_END = preload("uid://d2womvgn0i07n")

@export var animation_player: AnimationPlayer
@export var black: ColorRect 
@export var fireball_l: AnimatedSprite2D
@export var fireball_r: AnimatedSprite2D 
@export var overseer: Sprite2D 
@export var whole_wing: Sprite2D 
@export var whole_wing_particles: GPUParticles2D
@export var gpu_particles_2d: GPUParticles2D
@export var gpu_particles_2d_2: GPUParticles2D
@export var gpu_particles_2d_3: GPUParticles2D
@export var gpu_particles_2d_4: GPUParticles2D
@export var beginning: CanvasLayer
@export var end_dialog:Array[BaseDialog]
@export var end_dialog2:Array[BaseDialog]
@export var end_dialog3:Array[BaseDialog]
@onready var crash: AudioStreamPlayer = $Audio/Crash

var effect
var finish_tween:Tween
var fireball_tween:Tween

var end_fireball_group

var round3_f:bool=false
var rad:float=0


func _ready() -> void:
	#call_deferred("rand_update_effect")
	#BGM.play()
	animation_player.play("new_animation")
	set_process_input(false)
	await BattleClock.wait_seconds(11.834)
	super._ready()
	fireball_l.play("default")
	fireball_r.play("default")
	set_process_input(true)

func rand_update_effect():
	Global.create_rand_update_effect(self)

	
func _on_enemy_dead(_index:int):
	attack_bar.enemy_dead.disconnect(_on_enemy_dead)
	attack_bar.enemy_dead.connect(_on_enemy_dead2)
	enemy_illustration.change_expression(ExpressionSet.HURT) # 原下标 4
	create_explode_effect(Vector2(320,150),Vector2.ONE*0.6,Color.RED)
	create_blood_effect(Vector2(320,150))
	set_process_input(false)
	await BattleClock.wait_seconds(0.8)
	dialog_director.play(end_dialog3)
	dialog_director.finished.disconnect(enemy_turn_finished)
	dialog_director.main_panel().dialog_processed.connect(func(index):
												if index==5:
													# 立绘表情由 end_dialog3 里那句对话自带（CRY），这里只负责扣血
													attack_bar.coverage_damage=284600
													await BattleClock.wait_seconds(0.2)
													attack_bar.attack_cursor.effect())
func _on_enemy_dead2(_index:int):
	create_explode_effect(Vector2(320,150),Vector2.ONE*0.6,Color.RED)
	create_blood_effect(Vector2(320,150))
	dialog_director.close_all()
	await BattleClock.wait_seconds(0.8)
	var progress:float=0
	enemy_dead_player.play()
	while progress<1:
		progress+=0.02
		enemy_illustration.modulate.a-=0.02
		await get_tree().physics_frame
		enemy_illustration.material.set_shader_parameter("strength",progress)
		
	Global.change_scene_to_packed(BATTLE_END,4,Color.BLACK)

func enemy_turn_finished(mgr:BaseEnemyTurnManager=null):
	if round_index==9:
		if mgr:
			_fade_and_free(mgr,2.0)
		end_fireball_group=CIRCLE_FIREBALL_GROUP.instantiate()
		end_fireball_group.explode_duration=9999999
		end_fireball_group.amount=16
		add_child(end_fireball_group)
		await BattleClock.wait_seconds(3)
		
		BGM.stop()
		
		gpu_particles_2d.emitting=false
		gpu_particles_2d_2.emitting=false
		gpu_particles_2d_3.emitting=false
		gpu_particles_2d_4.emitting=false
		whole_wing_particles.emitting=false
		
		await BattleClock.wait_seconds(2)
		dialog_director.finished.disconnect(enemy_turn_bullet)
		dialog_director.play(end_dialog)
		await dialog_director.finished
		dialog_director.finished.connect(enemy_turn_finished)
		battle_data.player_status.attack=256000
		_play_ending_sequence()
		round_index+=1
		return
	
	if round_index==10:
		super.enemy_turn_finished(mgr)
		return
	
	
	match round_index:
		1:
			gpu_particles_2d_2.show()
			gpu_particles_2d.emitting=false
		4:
			gpu_particles_2d_3.show()
			gpu_particles_2d_4.show()
			gpu_particles_2d_2.emitting=false
			
	_start_round_transition(mgr)


## 淡出并回收一个节点。原来是 tween 回调里 queue_free，
## 回调落在哪一帧不确定 —— 弹幕的存活时刻也会跟着漂，所以按 tick 等。
func _fade_and_free(node: Node, seconds: float) -> void:
	var fade:=create_tween()
	fade.tween_property(node,"modulate:a",0.0,seconds)
	await BattleClock.wait_seconds(seconds)
	if is_instance_valid(node):
		node.queue_free()


## 最终演出：黑幕 + 部件切换 + 第二段对话（原来是一串 tween 回调，改成按 tick 等）
func _play_ending_sequence() -> void:
	var black_in:=create_tween()
	black_in.tween_property(black,"modulate:a",1.0,2.0)
	await BattleClock.wait_seconds(2)
	set_battleframe_polygon()
	enemy_illustration.change_expression(ExpressionSet.WORRIED)
	overseer.hide()
	whole_wing.hide()
	fireball_l.hide()
	fireball_r.hide()
	soul.hide()
	end_fireball_group.queue_free()
	button_container.position=BUTTON_CONTAINER_POSITION
	var black_out:=create_tween()
	black_out.tween_property(black,"modulate:a",0.0,1.0)
	await BattleClock.wait_seconds(1)
	dialog_director.play(end_dialog2)


## 回合之间的黑幕 + 复位（原来是 finish_tween 的回调，改成按 tick 等）
func _start_round_transition(mgr: BaseEnemyTurnManager) -> void:
	if finish_tween and finish_tween.is_running():
		finish_tween.kill()
	finish_tween=create_tween()
	finish_tween.tween_property(black,"modulate:a",1.0,1.0)
	await BattleClock.wait_seconds(1)
	fireball_l.position=Vector2(210,150)
	fireball_r.position=Vector2(430,150)
	fireball_l.modulate.a=1
	fireball_r.modulate.a=1
	fireball_l.rotation=0
	fireball_r.rotation=0
	round3_f=false
	super.enemy_turn_finished(mgr)
	finish_tween=create_tween()
	finish_tween.tween_property(black,"modulate:a",0.0,1.0)
	
func _process(delta: float) -> void:
	if round3_f:
		rad+=delta*-3.72
		fireball_l.position=Vector2(320,150)+ Vector2(50,0).rotated(rad)
		fireball_l.rotation=rad
		fireball_r.position=Vector2(320,150)+ Vector2(50,0).rotated(rad-PI)
		fireball_r.rotation=rad-PI
func _on_round_end(index:int) -> void:
	if fireball_tween and fireball_tween.is_running():
		fireball_tween.kill()
	match round_index:
		0:
			fireball_tween=create_tween()
			fireball_tween.tween_property(fireball_l,"position",Vector2(300,30),1)
			fireball_tween.parallel().tween_property(fireball_r,"position",Vector2(340,30),1)
		1:
			fireball_tween=create_tween()
			fireball_tween.tween_property(fireball_l,"position",Vector2(-20,150),0.5)
			fireball_tween.parallel().tween_property(fireball_r,"position",Vector2(660,150),0.5)
		2:
			fireball_tween=create_tween()
			fireball_tween.tween_property(fireball_l,"modulate:a",0,0.5)
			fireball_tween.parallel().tween_property(fireball_r,"modulate:a",0,0.5)
			
			fireball_tween.tween_callback(func():
												rad=-0.5*-3.72
												round3_f=true)

			fireball_tween.tween_property(fireball_l,"modulate:a",1,0.5)
			fireball_tween.parallel().tween_property(fireball_r,"modulate:a",1,0.5)
		5:
			fireball_tween=create_tween()
			fireball_tween.tween_property(fireball_l,"position",Vector2(300,30),1)
			fireball_tween.parallel().tween_property(fireball_r,"position",Vector2(340,30),1)
		7:
			fireball_tween=create_tween()
			fireball_tween.tween_property(fireball_l,"position",Vector2(230,40),1)
			fireball_tween.parallel().tween_property(fireball_r,"position",Vector2(410,40),1)
			fireball_tween.parallel().tween_property(whole_wing,"scale:x",1,1).from(0)
			fireball_tween.parallel().tween_callback(func():whole_wing.show();crash.play();create_explode_effect(Vector2(320,150),Vector2.ONE*0.7))
			fireball_tween.tween_callback(func():whole_wing_particles.show())
		9:
			fireball_tween=create_tween()
			fireball_tween.tween_property(fireball_l,"position",Vector2(210,40),1)
			fireball_tween.parallel().tween_property(fireball_r,"position",Vector2(430,40),1)
func _on_round_start(index: int) -> void:
	pass # Replace with function body.


func _on_enemy_round_start(index: int) -> void:
	match round_index:
		4:
			fireball_tween=create_tween()
			fireball_tween.tween_interval(4)
			fireball_tween.tween_property(fireball_l,"position",Vector2(240,250),1)
			fireball_tween.parallel().tween_property(fireball_r,"position",Vector2(410,60),1)
			fireball_tween.tween_property(fireball_l,"position",Vector2(240,60),1).set_delay(3)
			fireball_tween.parallel().tween_property(fireball_r,"position",Vector2(400,260),1).set_delay(3)
