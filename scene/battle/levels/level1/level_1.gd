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
	await get_tree().create_timer(11.834).timeout
	super._ready()
	fireball_l.play("default")
	fireball_r.play("default")
	set_process_input(true)

func rand_update_effect():
	Global.create_rand_update_effect(self)

	
func _on_enemy_dead():
	attack_bar.enemy_dead.disconnect(_on_enemy_dead)
	attack_bar.enemy_dead.connect(_on_enemy_dead2)
	enemy_illustration.change_illustration(4)
	create_explode_effect(Vector2(320,150),Vector2.ONE*0.6,Color.RED)
	create_blood_effect(Vector2(320,150))
	set_process_input(false)
	await get_tree().create_timer(0.8).timeout
	dialog_panel.show_dialog(end_dialog3)
	dialog_panel.finished.disconnect(enemy_turn_finished)
	dialog_panel.dialog_processed.connect(func(index):
												if index==5:
													enemy_illustration.change_illustration(5)
													attack_bar.coverage_damage=284600
													await get_tree().create_timer(0.2).timeout
													attack_bar.attack_cursor.effect())
func _on_enemy_dead2():
	create_explode_effect(Vector2(320,150),Vector2.ONE*0.6,Color.RED)
	create_blood_effect(Vector2(320,150))
	dialog_panel.close()
	await get_tree().create_timer(0.8).timeout
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
		var end_tween=create_tween()
		if mgr:
			end_tween.tween_property(mgr,"modulate:a",0,2)
			end_tween.tween_callback(mgr.queue_free)
		end_fireball_group=CIRCLE_FIREBALL_GROUP.instantiate()
		end_fireball_group.explode_duration=9999999
		end_fireball_group.amount=16
		add_child(end_fireball_group)
		await get_tree().create_timer(3).timeout
		
		BGM.stop()
		
		gpu_particles_2d.emitting=false
		gpu_particles_2d_2.emitting=false
		gpu_particles_2d_3.emitting=false
		gpu_particles_2d_4.emitting=false
		whole_wing_particles.emitting=false
		
		await get_tree().create_timer(2).timeout
		dialog_panel.finished.disconnect(enemy_turn_bullet)
		dialog_panel.show_dialog(end_dialog)
		await dialog_panel.finished
		dialog_panel.finished.connect(enemy_turn_finished)
		battle_data.player_status.attack=256000
		end_tween=create_tween()
		end_tween.tween_property(black,"modulate:a",1,2)
		end_tween.tween_callback(func(): set_battleframe_polygon();\
									enemy_illustration.change_illustration(2);\
									overseer.hide();whole_wing.hide();\
									fireball_l.hide();fireball_r.hide();\
									soul.hide();\
									end_fireball_group.queue_free();\
									button_container.position=BUTTON_CONTAINER_POSITION)
		end_tween.tween_property(black,"modulate:a",0,1)
		end_tween.tween_callback(dialog_panel.show_dialog.bind(end_dialog2))
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
			
	if finish_tween and finish_tween.is_running():
		finish_tween.kill()
	finish_tween=create_tween()
	finish_tween.tween_property(black,"modulate:a",1,1)
	finish_tween.tween_callback(func():
									fireball_l.position=Vector2(210,150)
									fireball_r.position=Vector2(430,150)
									fireball_l.modulate.a=1
									fireball_r.modulate.a=1
									fireball_l.rotation=0
									fireball_r.rotation=0
									round3_f=false
									super.enemy_turn_finished(mgr))
	finish_tween.tween_property(black,"modulate:a",0,1)
	
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
