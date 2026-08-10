extends Control
class_name BattleManager
const SPR_ACTBT_CENTER_0 = preload("uid://bsqjsm41smset")
const SPR_ACTBT_CENTER_1 = preload("uid://cudthffq1bo84")
const SPR_FIGHTBT_CENTER_0 = preload("uid://cnx282i8sll4r")
const SPR_FIGHTBT_CENTER_1 = preload("uid://badvkitid30pw")
const SPR_ITEMBT_0 = preload("uid://3c3lvhsqifwx")
const SPR_ITEMBT_1 = preload("uid://cca78p1m0a7fk")
const SPR_SPAREBT_0 = preload("uid://6jjmmkw7g1v6")
const SPR_SPAREBT_1 = preload("uid://jcu2kptuk5l2")
const EXPLODE_EFFECT = preload("uid://djpv4bs5mo5ui")
const BLOOD_EFFECT = preload("uid://bqrgv5a3m6dys")

const SOUL_BUTTON_OFFSET=Vector2(16,21)
const SOUL_CHOICE_OFFSET=Vector2(-18,14)
const BUTTON_CONTAINER_POSITION=Vector2(30,430)
const BATTLE_FRAME_TEXT_POSITION=Vector2(48.0,308.0)

enum BattleState{
	ACTION,
	FIGHT,
	ACT,
	ITEM,
	MERCY,
	ENEMY_TURN
}
enum Choice{
	NONE,
	ENEMY,
	ACT,
	ITEM,
	MERCY
}

@export var state:BattleState:
	set(value):
		if value!=state:
			state=value
			state_changed.emit()
@export var squeak_player: AudioStreamPlayer
@export var select_player: AudioStreamPlayer
@export var battle_data:BattleData
@export var autostart:bool=false
@export var fight_button:BattleActionButton
@export var act_button:BattleActionButton
@export var item_button:BattleActionButton
@export var mercy_button:BattleActionButton
@export var soul:Soul
@export var attack_bar: AttackBar
@export var battle_frame_text:BattleFrameText
@export var battle_frame_border: BattleFrameBorder
@export var dialog_panel: DialogPanel
@export var bullet_player: AudioStreamPlayer
@export var button_container: HBoxContainer
@export var debug_round_input: SpinBox
@export var player_status: PlayerStatusPanel
@export var highest_layer: CanvasLayer
@export var enemy_illustration:EnemyIllustration
@onready var buttons:Array[BattleActionButton]=[fight_button,act_button,item_button,mercy_button]

var choice_progress:Choice:
	set(value):
		if choice_progress!=value:
			choice_progress=value
			choice_changed.emit()
var button_container_tween:Tween
var polygon_tween:Tween
var button_index:int=0
var choice_index:int=0
var page_index:int=0
var round_index:int=0

##玩家回合开始时所有场景准备好后触发
signal round_start(index:int)
##玩家回合结束时所有场景准备好后触发
signal round_end(index:int)
##敌人对话后，回合开始时所有场景准备好后触发
signal enemy_round_start(index:int)


##状态机改变
signal state_changed()
##玩家选择对象改变
signal choice_changed()

func _ready() -> void:
	button_container.position=BUTTON_CONTAINER_POSITION
	dialog_panel.finished.connect(enemy_turn_bullet)
	attack_bar.attack_done.connect(enemy_turn_start)
	attack_bar.enemy_dead.connect(_on_enemy_dead)
	soul.player_status=battle_data.player_status
	player_status.player_status=battle_data.player_status
	player_status.init()
	
	if !autostart:
		action_start()
	else:
		enemy_turn_start()
		
func action_start():
	soul.show()
	battle_frame_text.show_dialog([battle_data.rounds[round_index].battleframe_text])
	#button_index=0
	soul.global_position=buttons[button_index].global_position+SOUL_BUTTON_OFFSET
	_action_change_button()
	await get_tree().process_frame
	state=BattleState.ACTION
	round_start.emit(round_index)
	
	
func enemy_turn_start():
	
	state=BattleState.ENEMY_TURN
	fight_button.texture=SPR_FIGHTBT_CENTER_0
	act_button.texture=SPR_ACTBT_CENTER_0
	item_button.texture=SPR_ITEMBT_0
	mercy_button.texture=SPR_SPAREBT_0
	round_end.emit(round_index)
	
	if button_container_tween and button_container_tween.is_running():
		button_container_tween.kill()
	button_container_tween=create_tween()
	button_container_tween.tween_property(button_container,"position",BUTTON_CONTAINER_POSITION+Vector2(0,100),0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	for i in battle_frame_text.finished.get_connections():
		battle_frame_text.finished.disconnect(i["callable"])
	if !battle_data.rounds[round_index].dialog_list.is_empty():
		dialog_panel.show_dialog(battle_data.rounds[round_index].dialog_list)
	else:
		enemy_turn_bullet()
func enemy_turn_bullet():
	if !battle_data.rounds[round_index].manager:
		enemy_turn_finished()
		return
	var enemy_turn_manager=battle_data.rounds[round_index].manager.new() as BaseEnemyTurnManager
	enemy_turn_manager.master=self
	enemy_turn_manager.finished.connect(enemy_turn_finished)
	battle_frame_border.add_sibling(enemy_turn_manager)
	soul.show()
	enemy_turn_manager.start()
	enemy_round_start.emit(round_index)

func enemy_turn_finished(mgr:BaseEnemyTurnManager=null):
	if mgr:
		mgr.queue_free()
	soul.hide()
	
	if button_container_tween and button_container_tween.is_running():
		button_container_tween.kill()
	button_container_tween=create_tween()
	button_container_tween.tween_property(button_container,"position",BUTTON_CONTAINER_POSITION,0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await set_battleframe_polygon_trans()
	round_index=clamp(round_index+1,0,battle_data.rounds.size()-1)
	action_start()


func _input(event: InputEvent) -> void:
	match state:
		BattleState.ACTION:
			if event.is_action_pressed("left",true):
				button_index=fposmod(button_index-1,4)
				_action_change_button()
			elif event.is_action_pressed("right",true):
				button_index=fposmod(button_index+1,4)
				_action_change_button()
			if event.is_action_pressed("accept"):
				select_player.play()
				match buttons[button_index].type:
					BattleActionButton.Type.FIGHT:
						_fight_1()
					BattleActionButton.Type.ACT:
						_act1()
					BattleActionButton.Type.ITEM:
						if !battle_data.player_status.backpack.is_empty():
							_item1()
					BattleActionButton.Type.MERCY:
						_mercy1()
		BattleState.FIGHT:
			if choice_progress==Choice.ENEMY:
				if event.is_action_pressed("accept"):
					_fight_2()
					select_player.play()
				elif event.is_action_pressed("cancel"):
					_return_button()
		BattleState.ACT:
			if choice_progress==Choice.ENEMY:
				if event.is_action_pressed("accept"):
					_act2(0)
					select_player.play()
				elif event.is_action_pressed("cancel"):
					_return_button()
			elif choice_progress==Choice.ACT:
				if event.is_action_pressed("accept"):
					_act3(0)
					select_player.play()
				elif event.is_action_pressed("cancel"):
					_act1()
					squeak_player.play()
		BattleState.ITEM:
			if choice_progress==Choice.ITEM:
				if event.is_action_pressed("accept"):
					return
					
				elif event.is_action_pressed("cancel"):
					_return_button()
		BattleState.MERCY:
			if choice_progress==Choice.MERCY:
				if event.is_action_pressed("accept"):
					select_player.play()
					_clear_frame_and_turn()
					
				elif event.is_action_pressed("cancel"):
					_return_button()
				
				
func _fight_1():
	choice_progress=Choice.ENEMY
	state=BattleState.FIGHT
	battle_frame_text.skip()
	battle_frame_text.show_enemy_choose()
	soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET

func _fight_2():
	attack_bar.attack()
	choice_progress=Choice.NONE
	battle_frame_text.hide_all()
	soul.position=Vector2(10000,10000)
	soul.hide()
	
func _act1():
	choice_progress=Choice.ENEMY
	state=BattleState.ACT
	battle_frame_text.skip()
	battle_frame_text.show_choose(choice_progress)
	soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET

func _act2(enemy_index:int):
	choice_progress=Choice.ACT
	battle_frame_text.show_choose(choice_progress)
	soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET

func _act3(enemy_index:int):
	choice_progress=Choice.NONE
	var act_dialog=BaseDialog.new()
	act_dialog.content=("* "+battle_data.enemys[enemy_index].id+" "
						+battle_data.enemys[enemy_index].descriptive_attack+" ATK "
						+battle_data.enemys[enemy_index].descriptive_defense+" DEF \n"
						+"* "+battle_data.enemys[enemy_index].description)
	battle_frame_text.show_dialog([act_dialog])
	battle_frame_text.finished.connect(_clear_frame_and_turn)
	soul.position=Vector2(10000,10000)
	soul.hide()

func _item1():
	choice_progress=Choice.ITEM
	state=BattleState.ITEM
	battle_frame_text.skip()
	battle_frame_text.show_choose(choice_progress)
	soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET

func _mercy1():
	choice_progress=Choice.MERCY
	state=BattleState.MERCY
	battle_frame_text.skip()
	battle_frame_text.show_choose(choice_progress)
	soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET


func _clear_frame_and_turn():
	soul.position=Vector2(10000,10000)
	soul.hide()
	battle_frame_text.hide_all()
	enemy_turn_start()


func _return_button():
	_action_change_button()
	choice_progress=Choice.NONE
	state=BattleState.ACTION
	battle_frame_text.hide_all()
	battle_frame_text.description.show()



func _action_change_button():
	match button_index:
		0:
			fight_button.texture=SPR_FIGHTBT_CENTER_1
			act_button.texture=SPR_ACTBT_CENTER_0
			item_button.texture=SPR_ITEMBT_0
			mercy_button.texture=SPR_SPAREBT_0
			
		1:
			fight_button.texture=SPR_FIGHTBT_CENTER_0
			act_button.texture=SPR_ACTBT_CENTER_1
			item_button.texture=SPR_ITEMBT_0
			mercy_button.texture=SPR_SPAREBT_0
		2:
			fight_button.texture=SPR_FIGHTBT_CENTER_0
			act_button.texture=SPR_ACTBT_CENTER_0
			item_button.texture=SPR_ITEMBT_1
			mercy_button.texture=SPR_SPAREBT_0
		3:
			fight_button.texture=SPR_FIGHTBT_CENTER_0
			act_button.texture=SPR_ACTBT_CENTER_0
			item_button.texture=SPR_ITEMBT_0
			mercy_button.texture=SPR_SPAREBT_1
	soul.global_position=buttons[button_index].global_position+SOUL_BUTTON_OFFSET
	squeak_player.play()

func _on_button_action_selected(type:BattleActionButton.Type):
	print(type)


func direction_to_soul(from:Vector2):
	return from.direction_to(soul.global_position)

func set_battleframe_polygon(polygon:PackedVector2Array=[Vector2(28.0,288.0),Vector2(612.0,288.0),Vector2(612.0,420.0),Vector2(28.0,420.0)]):
	battle_frame_border.collision.polygon=polygon
	battle_frame_border.queue_redraw()
func set_battleframe_polygon_trans(polygon:PackedVector2Array=[Vector2(28.0,288.0),Vector2(612.0,288.0),Vector2(612.0,420.0),Vector2(28.0,420.0)],duration:float=0.8,trans:Tween.TransitionType=Tween.TransitionType.TRANS_QUAD,ease:Tween.EaseType=Tween.EaseType.EASE_OUT):
	if polygon_tween and polygon_tween.is_running():
		polygon_tween.kill()
	polygon_tween=create_tween()
	var p=battle_frame_border.collision.polygon
	polygon_tween.parallel().tween_method(set_battleframe_polygon,p,polygon,duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(duration).timeout
	
func play_bullet_sound(stream: AudioStream, from_offset: float = 0, volume_db: float = 0, pitch_scale: float = 1.0):
	var playback=bullet_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	playback.play_stream(stream,from_offset,volume_db,pitch_scale)

func create_explode_effect(pos:Vector2 ,explode_scale:Vector2=Vector2.ONE,color:Color=Color.WHITE):
	var ex=EXPLODE_EFFECT.instantiate() as Node2D
	ex.scale=explode_scale
	ex.position=pos
	ex.modulate=color
	if highest_layer:
		highest_layer.add_child(ex)
	else:
		add_child(ex)

func create_blood_effect(pos:Vector2 ,explode_scale:Vector2=Vector2.ONE):
	var ex=BLOOD_EFFECT.instantiate() as Node2D
	ex.scale=explode_scale
	ex.position=pos
	if highest_layer:
		highest_layer.add_child(ex)
	else:
		add_child(ex)

func _debug_add_hp():
	battle_data.player_status.hp=999
	
func _debug_change_round():
	if debug_round_input:
		round_index=debug_round_input.value

func _on_enemy_dead():
	pass
