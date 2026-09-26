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
@export var dialog_panels: Array[DialogPanel] = []

## 主对话框（第一个），单敌人场景和老代码直接用这个。
var dialog_panel: DialogPanel:
	get:
		return dialog_panels[0] if not dialog_panels.is_empty() else null
@export var bullet_player: AudioStreamPlayer
@export var enemy_dead_player: AudioStreamPlayer
@export var snd_heal: AudioStreamPlayer
@export var button_container: HBoxContainer
@export var debug_round_input: SpinBox
@export var player_status: PlayerStatusPanel
@export var highest_layer: CanvasLayer
## 每个敌人的立绘，下标 = 敌人下标（和 dialog_panels、battle_data.enemys 对齐）
@export var enemy_illustrations: Array[EnemyIllustration] = []
## 敌人死亡时立绘淡出的时长（0 = 立刻消失）
@export var enemy_death_fade_duration: float = 0.6

## 主立绘（第一个），Boss 关卡的老代码直接用这个
var enemy_illustration: EnemyIllustration:
	get:
		return enemy_illustrations[0] if not enemy_illustrations.is_empty() else null
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
##一段对话全部播完（所有批次都播完，替代原来的 dialog_panel.finished）
signal dialog_finished()
##所有敌人都死了（要不要切胜利/结算场景由关卡脚本决定）
signal all_enemies_dead()

func _ready() -> void:
	button_container.position=BUTTON_CONTAINER_POSITION
	dialog_finished.connect(enemy_turn_bullet)
	attack_bar.attack_done.connect(enemy_turn_start)
	attack_bar.enemy_dead.connect(_on_enemy_dead)
	soul.player_status=battle_data.player_status
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
	soul.position=Vector2(10000,10000)
	soul.hide()
	
	_display_button(true)
	
	for i in battle_frame_text.finished.get_connections():
		battle_frame_text.finished.disconnect(i["callable"])
	if !battle_data.rounds[round_index].dialog_list.is_empty():
		play_dialog_list(battle_data.rounds[round_index].dialog_list)
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


## ===== 多敌人对话导演 =====
## dialog_list 的元素规则：
## - 单句（BaseDialog / ExpressionDialog）：第 0 个敌人说的（ExpressionDialog 可以填 enemy_index），
##   连续的单句会自动合并成同一批，所以单敌人时的表现和以前完全一样（dialog_processed 下标也不变）
## - DialogBatch：一批“同时说”的对话，里面每句自己指定 enemy_index
## 一批里同一个敌人的多句按顺序显示在它自己的对话框上，不同敌人之间同时显示；
## 一批全部说完才轮到下一批，全部播完发 dialog_finished。

var _dialog_batches: Array = []
var _dialog_batch_index: int = 0
var _pending_panels: int = 0
## 每次 play_dialog_list / close_dialogs 都会加一，用来作废已经排队的延迟调用
var _dialog_generation: int = 0


## 播放一段对话
func play_dialog_list(dialogs: Array) -> void:
	_dialog_generation += 1
	_clear_dialog_panel_connections()
	_dialog_batches = _split_dialog_batches(dialogs)
	_dialog_batch_index = -1
	_next_dialog_batch()


## 关掉所有对话框（原来 dialog_panel.close() 的多敌人版本）
func close_dialogs() -> void:
	_dialog_generation += 1
	_clear_dialog_panel_connections()
	_dialog_batches = []
	_dialog_batch_index = 0
	_pending_panels = 0
	for panel in dialog_panels:
		if panel:
			panel.close()


## 第 index 个敌人的对话框，没有就用第一个能用的（并报警说明原因）
func panel_for_enemy(index: int) -> DialogPanel:
	var panel := panel_at(index)
	if panel != null:
		return panel
	var fallback := first_valid_dialog_panel()
	if fallback == null:
		push_warning("敌人 %d 没有可用的对话框：dialog_panels 是空的，或者里面全是空节点（检查节点路径，以及根节点 node_paths 里有没有 dialog_panels）。" % index)
		return null
	push_warning("敌人 %d 没有自己的对话框（dialog_panels 第 %d 个是空节点或不存在），先用 %s。" % [index, index, fallback.name])
	return fallback


## 第一个真正接上的对话框，没有就返回 null
func first_valid_dialog_panel() -> DialogPanel:
	for panel in dialog_panels:
		if panel != null:
			return panel
	return null


## 这个对话框能不能显示；不能就报警并跳过这一组
func _can_show_dialog_on(panel: DialogPanel, enemy_index: int) -> bool:
	if panel == null:
		return false # panel_for_enemy 已经报过警了
	if panel.dialog_label == null:
		push_warning("敌人 %d 的对话框 %s 没有接 dialog_label，这组对白没法显示，已跳过。" % [enemy_index, panel.name])
		return false
	return true


## 第 index 个敌人的对话框；越界返回 null（不回退）
func panel_at(index: int) -> DialogPanel:
	if index < 0 or index >= dialog_panels.size():
		return null
	return dialog_panels[index]


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


## 把 dialog_list 切成一批一批
func _split_dialog_batches(dialogs: Array) -> Array:
	var batches: Array = []
	var pending: Array = [] # 连续的单句攒成一批
	for dialog in dialogs:
		if dialog == null:
			continue
		if dialog is DialogBatch:
			_flush_pending_batch(batches, pending)
			var batch := _group_by_enemy((dialog as DialogBatch).dialogs)
			if not batch.is_empty():
				batches.append(batch)
		else:
			pending.append(dialog)
	_flush_pending_batch(batches, pending)
	return batches


func _flush_pending_batch(batches: Array, pending: Array) -> void:
	if pending.is_empty():
		return
	batches.append(_group_by_enemy(pending))
	pending.clear()


static func _enemy_index_of(dialog: Variant) -> int:
	if dialog is ExpressionDialog:
		return (dialog as ExpressionDialog).enemy_index
	return 0


## 一批里按敌人分组，保持出现顺序：[[{enemy_index, dialogs}, ...], ...]
static func _group_by_enemy(dialogs: Array) -> Array:
	var order: Array[int] = []
	var groups: Dictionary = {}
	for value in dialogs:
		var dialog := value as BaseDialog
		if dialog == null:
			continue
		var index := _enemy_index_of(dialog)
		if not groups.has(index):
			var group: Array[BaseDialog] = []
			groups[index] = group
			order.append(index)
		(groups[index] as Array[BaseDialog]).append(dialog)
	var result: Array = []
	for index in order:
		result.append({"enemy_index": index, "dialogs": groups[index]})
	return result


func _next_dialog_batch(generation: int = -1) -> void:
	if generation >= 0 and generation != _dialog_generation:
		return # 这段对话已经被新的 play_dialog_list / close_dialogs 顶掉了
	_dialog_batch_index += 1
	if _dialog_batch_index >= _dialog_batches.size():
		_pending_panels = 0
		dialog_finished.emit()
		return
	var batch: Array = _dialog_batches[_dialog_batch_index]
	# 先把这一批的对白按对话框归拢：同一个对话框（比如越界回退）里的对白合并成一段，避免同一帧显示两次
	var panel_order: Array[DialogPanel] = []
	var panel_dialogs: Dictionary = {}
	for group: Dictionary in batch:
		var panel := panel_for_enemy(group["enemy_index"])
		if not _can_show_dialog_on(panel, group["enemy_index"]):
			continue
		if not panel_dialogs.has(panel):
			var queue: Array[BaseDialog] = []
			panel_dialogs[panel] = queue
			panel_order.append(panel)
		var group_dialogs: Array[BaseDialog] = group["dialogs"]
		(panel_dialogs[panel] as Array[BaseDialog]).append_array(group_dialogs)
	if panel_order.is_empty():
		_next_dialog_batch()
		return
	# 只把“真的显示出来了”的对话框算进等待列表：坏掉的面板不会把整段对话卡死
	var shown: Array[DialogPanel] = []
	for panel in panel_order:
		panel.show_dialog(panel_dialogs[panel])
		if panel.visible:
			shown.append(panel)
		else:
			push_warning("对话框 %s 没能显示，这一组对白跳过。" % panel.name)
	_pending_panels = shown.size()
	if _pending_panels <= 0:
		_next_dialog_batch()
		return
	for panel in shown:
		panel.finished.connect(_on_batch_panel_finished, CONNECT_ONE_SHOT)
	_close_inactive_panels(panel_order)


func _on_batch_panel_finished() -> void:
	if _pending_panels <= 0:
		return # 这一批已经收尾了，多出来的 finished 忽略掉
	_pending_panels -= 1
	if _pending_panels <= 0:
		# 等这一帧的调用栈退干净再开下一批：
		# 面板的 hide()、标签的关输入这些都发生在信号回调“之后”，
		# 立刻在这里开下一批会被它们的收尾盖掉（面板被藏、输入被关）。
		_defer_next_dialog_batch(_dialog_generation)


func _defer_next_dialog_batch(generation: int) -> void:
	_next_dialog_batch.bind(generation).call_deferred()


func _close_inactive_panels(active: Array[DialogPanel]) -> void:
	for panel in dialog_panels:
		if panel and not active.has(panel):
			panel.close()


func _clear_dialog_panel_connections() -> void:
	for panel in dialog_panels:
		if panel and panel.finished.is_connected(_on_batch_panel_finished):
			panel.finished.disconnect(_on_batch_panel_finished)

func enemy_turn_finished(mgr:BaseEnemyTurnManager=null):
	if mgr:
		mgr.queue_free()
	soul.hide()
	
	_display_button()
	
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
				if event.is_action_pressed("accept"):
					_fight_2()
					select_player.play()
				elif event.is_action_pressed("cancel"):
					_return_button()
				elif event.is_action_pressed("left",true):
					_move_choice_cursor(selectable_enemies.size(),0,-1)
				elif event.is_action_pressed("right",true):
					_move_choice_cursor(selectable_enemies.size(),0,1)
				elif event.is_action_pressed("up",true):
					_move_choice_cursor(selectable_enemies.size(),-1,0)
				elif event.is_action_pressed("down",true):
					_move_choice_cursor(selectable_enemies.size(),1,0)
		BattleState.ACT:
			if choice_progress==Choice.ENEMY:
				if event.is_action_pressed("accept"):
					_act2(selected_enemy_index())
					select_player.play()
				elif event.is_action_pressed("cancel"):
					_return_button()
				elif event.is_action_pressed("left",true):
					_move_choice_cursor(selectable_enemies.size(),0,-1)
				elif event.is_action_pressed("right",true):
					_move_choice_cursor(selectable_enemies.size(),0,1)
				elif event.is_action_pressed("up",true):
					_move_choice_cursor(selectable_enemies.size(),-1,0)
				elif event.is_action_pressed("down",true):
					_move_choice_cursor(selectable_enemies.size(),1,0)
			elif choice_progress==Choice.ACT:
				if event.is_action_pressed("accept"):
					_act3(choice_index)
					select_player.play()
				elif event.is_action_pressed("cancel"):
					# 退回选敌列表，光标回到刚才那个敌人身上
					choice_index=maxi(0,selectable_enemies.find(act_enemy_index))
					_act1()
					squeak_player.play()
				elif event.is_action_pressed("left",true):
					_move_choice_cursor(act_list_for(act_enemy_index).size(),0,-1)
				elif event.is_action_pressed("right",true):
					_move_choice_cursor(act_list_for(act_enemy_index).size(),0,1)
				elif event.is_action_pressed("up",true):
					_move_choice_cursor(act_list_for(act_enemy_index).size(),-1,0)
				elif event.is_action_pressed("down",true):
					_move_choice_cursor(act_list_for(act_enemy_index).size(),1,0)
		BattleState.ITEM:
			
			if choice_progress==Choice.ITEM:
				if event.is_action_pressed("right"):
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
				elif event.is_action_pressed("left"):
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
				elif event.is_action_pressed("up"):
					if choice_index==2 or choice_index==3:
						choice_index-=2
					squeak_player.play()
					soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET
				elif event.is_action_pressed("down"):
					if choice_index==0 or choice_index==1:
						choice_index+=2
					squeak_player.play()
					soul.global_position=battle_frame_text.get_choice_position(choice_index)+SOUL_CHOICE_OFFSET
				if event.is_action_pressed("accept"):
					_item2(choice_index+page_index*4)
					
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
	var panel := panel_at(index)
	if panel:
		panel.close()
	if not has_living_enemy():
		all_enemies_dead.emit()
