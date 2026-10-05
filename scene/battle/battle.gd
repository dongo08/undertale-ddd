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
const DEAD_EFFECT = preload("uid://dfroi6v588n3k")
const GAME_OVER = preload("uid://b8rgd3l78wg6x")

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
## 对话导演：谁说话、面板怎么切全在它里面（场景里挂一个 DialogDirector 节点）
@export var dialog_director: DialogDirector
@export var bullet_player: AudioStreamPlayer
@export var enemy_dead_player: AudioStreamPlayer
@export var snd_heal: AudioStreamPlayer
@export var button_container: HBoxContainer
@export var debug_round_input: SpinBox
@export var player_status: PlayerStatusPanel
@export var highest_layer: CanvasLayer
## 每个敌人的立绘，下标 = 敌人下标（和 dialog_director.panels、battle_data.enemys 对齐）
@export var enemy_illustrations: Array[EnemyIllustration] = []
## 敌人死亡时立绘淡出的时长（0 = 立刻消失）
@export var enemy_death_fade_duration: float = 0.6

## 主立绘（第一个），Boss 关卡的老代码直接用这个
var enemy_illustration: EnemyIllustration:
	get:
		return enemy_illustrations[0] if not enemy_illustrations.is_empty() else null
@onready var buttons:Array[BattleActionButton]=[fight_button,act_button,item_button,mercy_button]

var enemy_turn_manager:BaseEnemyTurnManager
var choice_progress:Choice:
	set(value):
		if choice_progress!=value:
			choice_progress=value
			choice_changed.emit()
var button_container_tween:Tween
var polygon_tween:Tween
## 战斗框过渡的代次号：有更新的过渡时，旧的自己让位（碰撞框是 gameplay，必须逐 tick 插值）
var _polygon_trans_id: int = 0
var button_index:int=0
var choice_index:int=0
var page_index:int=0
var round_index:int=0

## ACT 列表里固定第一个显示的选项
const CHECK_ACT_NAME := "查看"
## 当前能选中的敌人下标（活着的敌人，顺序就是选敌列表的顺序）
var selectable_enemies:Array[int]=[]
## 进去 ACT 列表时锁定的敌人下标
var act_enemy_index:int=0

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
##所有敌人都死了（要不要切胜利/结算场景由关卡脚本决定）
signal all_enemies_dead()

func _ready() -> void:
	# 菜单输入开关（输入本身走 BattleInput 的物理帧采样，见 _physics_process）
	set_process_input(true)
	# 开局随机种子：回放时由回放系统先设好种子，这里不能覆盖
	if BattleInput.mode != BattleInput.Mode.PLAY:
		BattleRNG.begin_random()
	button_container.position=BUTTON_CONTAINER_POSITION
	# 对话相关的事都交给 DialogDirector（它自己管面板和批次）
	if dialog_director:
		dialog_director.finished.connect(enemy_turn_bullet)
	else:
		push_warning("没有接 dialog_director，这一场不会播对话。")
	attack_bar.attack_done.connect(enemy_turn_start)
	attack_bar.enemy_dead.connect(_on_enemy_dead)
	soul.player_status=battle_data.player_status
	soul.dead.connect(_on_player_dead)
	player_status.player_status=battle_data.player_status
	player_status.init()
	battle_frame_text.hide_all()
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
	# 等一个物理帧（不能用 process_frame：渲染帧和物理帧的比值会变，回放就对不上了）
	#await BattleClock.wait_ticks(1)
	state=BattleState.ACTION
	round_start.emit(round_index)
	
	
func enemy_turn_start():
	
	state=BattleState.ENEMY_TURN
	fight_button.texture=SPR_FIGHTBT_CENTER_0
	act_button.texture=SPR_ACTBT_CENTER_0
	item_button.texture=SPR_ITEMBT_0
	mercy_button.texture=SPR_SPAREBT_0
	round_end.emit(round_index)
	soul.position=Vector2(10000,10000)
	soul.hide()
	
	_display_button(true)
	
	for i in battle_frame_text.finished.get_connections():
		battle_frame_text.finished.disconnect(i["callable"])
	if !battle_data.rounds[round_index].dialog_list.is_empty() and dialog_director:
		dialog_director.play(battle_data.rounds[round_index].dialog_list)
	else:
		enemy_turn_bullet()
## 当前难度。唯一来源是 Global.difficulty，以后要做难度选择改那一个地方就行
func current_difficulty()->EnemyRoundSet.Difficulty:
	return Global.difficulty


## 第 index 轮该用哪个弹幕脚本（按当前难度取，取不到返回 null）
func manager_script_for_round(index:int)->GDScript:
	if battle_data==null or index<0 or index>=battle_data.rounds.size():
		return null
	return battle_data.rounds[index].manager_for(current_difficulty())


func enemy_turn_bullet():
	# 按当前难度取这一轮的弹幕脚本（想要的难度没做会自动回退）
	var manager_script:=manager_script_for_round(round_index)
	if !manager_script:
		enemy_turn_finished()
		return
	enemy_turn_manager=manager_script.new() as BaseEnemyTurnManager
	enemy_turn_manager.master=self
	enemy_turn_manager.finished.connect(enemy_turn_finished)
	battle_frame_border.add_sibling(enemy_turn_manager)
	soul.show()
	soul.move_init()
	enemy_turn_manager.start()
	enemy_round_start.emit(round_index)


## 对话相关的东西（谁说话、面板怎么切、批次怎么排）都在 DialogDirector 里，
## 这里只管“该放一段对话了” -> dialog_director.play(...)


## 第 index 个敌人的立绘；越界返回 null
func portrait_for_enemy(index: int) -> EnemyIllustration:
	if index < 0 or index >= enemy_illustrations.size():
		return null
	return enemy_illustrations[index]


## 让第 index 个敌人的立绘淡出消失（关卡脚本也能单独调）
func fade_out_enemy_portrait(index: int) -> void:
	var portrait := portrait_for_enemy(index)
	if portrait == null:
		return
	if enemy_death_fade_duration <= 0:
		portrait.hide()
		return
	var tween := create_tween()
	tween.tween_property(portrait, "modulate:a", 0.0, enemy_death_fade_duration)
	tween.tween_callback(portrait.hide)


func enemy_turn_finished(mgr:BaseEnemyTurnManager=null):
	if mgr:
		mgr.queue_free()
	soul.hide()
	
	_display_button()
	
	await set_battleframe_polygon_trans()
	round_index=clamp(round_index+1,0,battle_data.rounds.size()-1)
	action_start()


## 菜单输入：每物理帧从 BattleInput 读一次。
## set_process_input 现在只当“当前能不能操作”的开关（关卡脚本用它屏蔽演出期间的输入）。
func _physics_process(_delta: float) -> void:
	# 第一个物理帧里把输入流接上。
	# 放在这里而不是 _ready：采样器比本节点先跑，所以"流从下一帧开始喂"，
	# 这样不管场景是在帧边界还是帧中间加进树的，录制和回放的起点都对齐。
	if not BattleInput.is_started():
		BattleInput.attach()
	if is_processing_input():
		_tick_input()


func _tick_input() -> void:
	match state:
		BattleState.ACTION:
			if BattleInput.repeated(&"left"):
				button_index=fposmod(button_index-1,4)
				_action_change_button()
			elif BattleInput.repeated(&"right"):
				button_index=fposmod(button_index+1,4)
				_action_change_button()
			if BattleInput.just_pressed(&"accept"):
				select_player.play()
				page_index=0
				choice_index=0
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
				if BattleInput.just_pressed(&"accept"):
					_fight_2()
					select_player.play()
				elif BattleInput.just_pressed(&"cancel"):
					_return_button()
				elif BattleInput.repeated(&"left"):
					_move_choice_cursor(selectable_enemies.size(),0,-1)
				elif BattleInput.repeated(&"right"):
					_move_choice_cursor(selectable_enemies.size(),0,1)
				elif BattleInput.repeated(&"up"):
					_move_choice_cursor(selectable_enemies.size(),-1,0)
				elif BattleInput.repeated(&"down"):
					_move_choice_cursor(selectable_enemies.size(),1,0)
		BattleState.ACT:
			if choice_progress==Choice.ENEMY:
				if BattleInput.just_pressed(&"accept"):
					_act2(selected_enemy_index())
					select_player.play()
				elif BattleInput.just_pressed(&"cancel"):
					_return_button()
				elif BattleInput.repeated(&"left"):
					_move_choice_cursor(selectable_enemies.size(),0,-1)
				elif BattleInput.repeated(&"right"):
					_move_choice_cursor(selectable_enemies.size(),0,1)
				elif BattleInput.repeated(&"up"):
					_move_choice_cursor(selectable_enemies.size(),-1,0)
				elif BattleInput.repeated(&"down"):
					_move_choice_cursor(selectable_enemies.size(),1,0)
			elif choice_progress==Choice.ACT:
				if BattleInput.just_pressed(&"accept"):
					_act3(choice_index)
					select_player.play()
				elif BattleInput.just_pressed(&"cancel"):
					# 退回选敌列表，光标回到刚才那个敌人身上
					choice_index=maxi(0,selectable_enemies.find(act_enemy_index))
					_act1()
					squeak_player.play()
				elif BattleInput.repeated(&"left"):
					_move_choice_cursor(act_list_for(act_enemy_index).size(),0,-1)
				elif BattleInput.repeated(&"right"):
					_move_choice_cursor(act_list_for(act_enemy_index).size(),0,1)
				elif BattleInput.repeated(&"up"):
					_move_choice_cursor(act_list_for(act_enemy_index).size(),-1,0)
				elif BattleInput.repeated(&"down"):
					_move_choice_cursor(act_list_for(act_enemy_index).size(),1,0)
		BattleState.ITEM:
			
			if choice_progress==Choice.ITEM:
				if BattleInput.just_pressed(&"right"):
					if choice_index==1 and page_index==0 and battle_data.player_status.backpack.size()>=5:
						page_index=1
						choice_index=0
						battle_frame_text.show_choose(choice_progress)
					elif choice_index==3 and page_index==0 and battle_data.player_status.backpack.size()>=7:
						page_index=1
						choice_index=2
						battle_frame_text.show_choose(choice_progress)
					elif choice_index==0 and battle_data.player_status.backpack.size()>choice_index+page_index*4:
						choice_index+=1
					elif choice_index==2 and battle_data.player_status.backpack.size()>choice_index+page_index*4:
						choice_index+=1
					squeak_player.play()
					soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET
				elif BattleInput.just_pressed(&"left"):
					if choice_index==0 and page_index==1:
						page_index=0
						choice_index=1
						battle_frame_text.show_choose(choice_progress)
					elif choice_index==2 and page_index==1:
						page_index=0
						choice_index=3
						battle_frame_text.show_choose(choice_progress)
					elif choice_index==1 :
						choice_index-=1
					elif choice_index==3:
						choice_index-=1
					squeak_player.play()
					soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET
				elif BattleInput.just_pressed(&"up"):
					if choice_index==2 or choice_index==3:
						choice_index-=2
					squeak_player.play()
					soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET
				elif BattleInput.just_pressed(&"down"):
					if choice_index==0 or choice_index==1:
						choice_index+=2
					squeak_player.play()
					soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET
				if BattleInput.just_pressed(&"accept"):
					_item2(choice_index+page_index*4)
					
				elif BattleInput.just_pressed(&"cancel"):
					_return_button()
		BattleState.MERCY:
			if choice_progress==Choice.MERCY:
				if BattleInput.just_pressed(&"accept"):
					select_player.play()
					_clear_frame_and_turn()
					
				elif BattleInput.just_pressed(&"cancel"):
					_return_button()
				
				
func _fight_1():
	choice_progress=Choice.ENEMY
	state=BattleState.FIGHT
	battle_frame_text.skip()
	_refresh_selectable_enemies()
	battle_frame_text.show_choose(choice_progress)
	_soul_to_choice()

func _fight_2():
	if selectable_enemies.is_empty():
		push_warning("没有可以攻击的敌人。")
		return
	attack_bar.attack(selected_enemy_index())
	choice_progress=Choice.NONE
	battle_frame_text.hide_all()
	soul.position=Vector2(10000,10000)
	soul.hide()
	
func _act1():
	choice_progress=Choice.ENEMY
	state=BattleState.ACT
	battle_frame_text.skip()
	_refresh_selectable_enemies()
	battle_frame_text.show_choose(choice_progress)
	_soul_to_choice()

func _act2(enemy_index:int):
	choice_progress=Choice.ACT
	act_enemy_index=enemy_index
	# ACT 列表是另一个列表，光标从第一项开始
	choice_index=0
	battle_frame_text.show_choose(choice_progress)
	_soul_to_choice()

## act_index 是 ACT 列表里的下标：0 固定是“查看”
func _act3(act_index:int):
	choice_progress=Choice.NONE
	var enemy=enemy_at(act_enemy_index)
	var dialog:BaseDialog=null
	if act_index<=0:
		dialog=_check_dialog(enemy)
	else:
		var act=act_at(act_enemy_index,act_index-1)
		if act:
			dialog=act.dialog
	if dialog:
		battle_frame_text.show_dialog([dialog])
		battle_frame_text.finished.connect(_clear_frame_and_turn)
	else:
		_clear_frame_and_turn()
	soul.position=Vector2(10000,10000)
	soul.hide()

static func _check_dialog_content(enemy:EnemyStatus)->String:
	if enemy==null:
		return ""
	return ("* "+enemy.id+" "
			+enemy.descriptive_attack+" ATK "
			+enemy.descriptive_defense+" DEF \n"
			+"* "+enemy.description)

func _check_dialog(enemy:EnemyStatus)->BaseDialog:
	var act_dialog=BaseDialog.new()
	act_dialog.content=_check_dialog_content(enemy)
	return act_dialog


## ===== 选敌 =====
## 选敌列表只列活着的敌人（死掉的直接消失，后面的往上顶），
## choice_index 是光标在“这个列表”里的位置，不是敌人下标，
## 要敌人下标用 selected_enemy_index()。

## 第 index 个敌人；越界返回 null
func enemy_at(index:int)->EnemyStatus:
	if battle_data==null or index<0 or index>=battle_data.enemys.size():
		return null
	return battle_data.enemys[index]

## 第 index 个敌人的第 act_index 个自定义 ACT（不含“查看”）
func act_at(index:int,act_index:int)->EnemyAct:
	var enemy=enemy_at(index)
	if enemy==null or act_index<0 or act_index>=enemy.acts.size():
		return null
	return enemy.acts[act_index]

## 第 index 个敌人的 ACT 名字列表，“查看”永远第一个
func act_list_for(index:int)->Array[String]:
	var names:Array[String]=[CHECK_ACT_NAME]
	var enemy=enemy_at(index)
	if enemy:
		for act in enemy.acts:
			if act:
				names.append(act.act_name if not act.act_name.is_empty() else "???")
	return names

## 还有活着的敌人吗
func has_living_enemy()->bool:
	if battle_data==null:
		return false
	for enemy in battle_data.enemys:
		if enemy and enemy.hp>0:
			return true
	return false

## 重新算一遍可选敌人，并把光标夹回范围内
func _refresh_selectable_enemies()->void:
	selectable_enemies.clear()
	if battle_data:
		for i in battle_data.enemys.size():
			var enemy=battle_data.enemys[i]
			if enemy and enemy.hp>0:
				selectable_enemies.append(i)
	choice_index=clampi(choice_index,0,maxi(0,selectable_enemies.size()-1))

## 选敌光标指着哪个敌人
func selected_enemy_index()->int:
	if selectable_enemies.is_empty():
		return 0
	return selectable_enemies[clampi(choice_index,0,selectable_enemies.size()-1)]

func selected_enemy()->EnemyStatus:
	return enemy_at(selected_enemy_index())

func _soul_to_choice()->void:
	soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET

## 列表光标按网格移动：row_delta 上下、col_delta 左右，越界就不动
static func _next_choice_index(current:int,count:int,columns:int,row_delta:int,col_delta:int)->int:
	if count<=0:
		return 0
	columns=maxi(1,columns)
	var target:=current
	if col_delta!=0:
		var col:=current%columns
		var next_col:=col+col_delta
		if next_col<0 or next_col>=columns:
			return current
		target=current+col_delta
	elif row_delta!=0:
		target=current+row_delta*columns
	if target<0 or target>=count:
		return current
	return target

func _move_choice_cursor(count:int,row_delta:int,col_delta:int)->void:
	var columns:int=2
	if battle_frame_text and battle_frame_text.choices:
		columns=battle_frame_text.choices.columns
	var target:=_next_choice_index(choice_index,count,columns,row_delta,col_delta)
	if target==choice_index:
		return
	choice_index=target
	squeak_player.play()
	_soul_to_choice()


func _item1():
	choice_progress=Choice.ITEM
	state=BattleState.ITEM
	battle_frame_text.skip()
	battle_frame_text.show_choose(choice_progress)
	soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET

func _item2(item_index:int):
	choice_progress=Choice.NONE
	state=BattleState.ITEM
	var item=battle_data.player_status.backpack[item_index]
	if item is ConsumableItem:
		var dialog=BaseDialog.new()
		battle_data.player_status.hp=clamp(battle_data.player_status.hp+item.health,0,battle_data.player_status.max_hp)
		snd_heal.play()
		dialog.content=("* 你吃了%s。\n"%tr(item.id)
						+(("* 你回复了 %s HP!"%String.num(item.health,0)) if battle_data.player_status.hp<battle_data.player_status.max_hp
						else "* 你的 HP 已满。" ) )
		battle_frame_text.show_dialog([dialog])
		battle_data.player_status.backpack.erase(item)
	else:
		battle_frame_text.show_dialog(item.description)
	battle_frame_text.finished.connect(_clear_frame_and_turn)
	_hide_soul()

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
	# 战斗框的碰撞多边形决定灵魂能不能走过去 —— 这属于 gameplay，
	# 不能交给 tween（tween 的起点落在两个物理帧之间，实测灵魂坐标会差 0.3 像素），逐 tick 插值。
	# 缓动跟原来的 TRANS_QUAD + EASE_OUT 等价：1-(1-t)^2
	_polygon_trans_id += 1
	var my_id := _polygon_trans_id
	var from=battle_frame_border.collision.polygon
	var ticks := BattleClock.seconds_to_ticks(duration)
	for i in ticks:
		if _polygon_trans_id != my_id:
			return                      # 有更新的过渡，让位
		var t := float(i + 1) / float(ticks)
		var eased := 1.0 - pow(1.0 - t, 2.0)
		if from.size() == polygon.size():
			var points := PackedVector2Array()
			for k in from.size():
				points.append(from[k].lerp(polygon[k], eased))
			set_battleframe_polygon(points)
		await get_tree().physics_frame
	set_battleframe_polygon(polygon)
	
func play_bullet_sound(stream: AudioStream, from_offset: float = 0, volume_db: float = 0, pitch_scale: float = 1.0):
	if bullet_player == null or stream == null:
		return
	# 多音播放器得先 play() 才有 playback：原来没人在起点调 play()，
	# 所以 get_stream_playback() 会报 "Player is inactive" 然后拿到 null（子弹音效是哑的）
	if not bullet_player.playing:
		bullet_player.play()
	var playback=bullet_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if playback == null:
		return
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


func _hide_soul():
	soul.position=Vector2(10000,10000)
	soul.hide()

func _debug_add_hp():
	battle_data.player_status.hp=999
	
func _debug_change_round():
	if debug_round_input:
		round_index=debug_round_input.value

func _display_button(hide:bool=false):
	if button_container_tween and button_container_tween.is_running():
		button_container_tween.kill()
	if hide:
		button_container_tween=create_tween()
		button_container_tween.tween_property(button_container,"position",BUTTON_CONTAINER_POSITION+Vector2(0,100),0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		button_container_tween=create_tween()
		button_container_tween.tween_property(button_container,"position",BUTTON_CONTAINER_POSITION,0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_enemy_dead(index:int):
	enemy_dead_player.play()
	_refresh_selectable_enemies()
	# 默认表现：死掉的那个敌人立绘淡出、它自己的对话框关掉
	# （要自定义死亡演出就重写 _on_enemy_dead，Boss 关卡就是这么做的）
	fade_out_enemy_portrait(index)
	if dialog_director:
		dialog_director.close_panel(index)
	if not has_living_enemy():
		finish_replay(BattleReplay.Result.WIN)
		all_enemies_dead.emit()

func _on_player_dead():
	# 死了：先把这次录的回放存下来（reload 会把场景整个换掉）
	finish_replay(BattleReplay.Result.DEAD)
	var dead_effect=DEAD_EFFECT.instantiate() as Node2D
	dead_effect.position=soul.position
	if enemy_turn_manager:
		enemy_turn_manager.queue_free()
	for i in get_children():
		if i !=soul and i.has_method("hide"):
			i.hide()
		BGM.stop(0)
	add_child(dead_effect)
	soul.reparent(get_tree().root)
	await BattleClock.wait_seconds(3)
	Global.change_scene_to_packed(GAME_OVER,0)

## 回放的校验值：录制和播放结束时各算一次，对不上说明这份回放跑歪了
func replay_checksum() -> int:
	var parts := "%d|%.4f|%.4f,%.4f|%d" % [
		round_index, battle_data.player_status.hp, soul.position.x, soul.position.y, BattleInput.progress_ticks()
	]
	return parts.hash()


## 战斗结束：录制模式存档，播放模式校验（返回是否顺利）
func finish_replay(result: int) -> bool:
	if BattleReplay.playing:
		return BattleReplay.finish_playback(replay_checksum())
	BattleReplay.end_battle(result, replay_checksum())
	return not BattleReplay.last_saved_path.is_empty()
