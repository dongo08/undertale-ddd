extends Node
class_name DialogDirector

## 多敌人对话导演：谁说话、什么时候说、说在哪块面板上，全在这里。
## BattleManager 只负责“该放一段对话了”，具体怎么播交给这个节点。
##
## play() 的 dialogs 元素规则：
## - 单句（BaseDialog / ExpressionDialog）：第 0 个敌人说的（ExpressionDialog 可以填 enemy_index），
##   连续的单句会自动合并成同一批，所以单敌人时的表现和以前完全一样（dialog_processed 下标也不变）
## - DialogBatch：一批“同时说”的对话，里面每句自己指定 enemy_index
## 一批里同一个敌人的多句按顺序显示在它自己的对话框上，不同敌人之间同时显示；
## 一批全部说完才轮到下一批，全部播完发 finished。

## 每个敌人一个对话框，下标 = 敌人下标（和 battle_data.enemys 对齐）
## 面板和这个节点是兄弟时，路径写成 ../PanelContainer
@export var panels: Array[DialogPanel] = []

## 一段对话全部播完（所有批次都播完）
signal finished()

var _batches: Array = []
var _batch_index: int = 0
var _pending_panels: int = 0
## 每次 play / close_all 都会加一，用来作废已经排队的延迟调用
var _generation: int = 0


## 播放一段对话
func play(dialogs: Array) -> void:
	_generation += 1
	_clear_panel_connections()
	_batches = _split_batches(dialogs)
	_batch_index = -1
	_next_batch()


## 关掉所有对话框
func close_all() -> void:
	_generation += 1
	_clear_panel_connections()
	_batches = []
	_batch_index = 0
	_pending_panels = 0
	for panel in panels:
		if panel:
			panel.close()


## 关掉第 index 个敌人的对话框（敌人死掉的时候用）
func close_panel(index: int) -> void:
	var panel := panel_at(index)
	if panel:
		panel.close()


## 正在播对话吗
func is_playing() -> bool:
	return _pending_panels > 0


## 第 index 个敌人的对话框；越界返回 null（不回退）
func panel_at(index: int) -> DialogPanel:
	if index < 0 or index >= panels.size():
		return null
	return panels[index]


## 主对话框（第一个），接 dialog_processed 之类的老写法用这个
func main_panel() -> DialogPanel:
	return panel_at(0)


## 第一个真正接上的对话框，没有就返回 null
func first_valid_panel() -> DialogPanel:
	for panel in panels:
		if panel != null:
			return panel
	return null


## 第 index 个敌人的对话框，没有就用第一个能用的（并报警说明原因）
func panel_for_enemy(index: int) -> DialogPanel:
	var panel := panel_at(index)
	if panel != null:
		return panel
	var fallback := first_valid_panel()
	if fallback == null:
		push_warning("敌人 %d 没有可用的对话框：panels 是空的，或者里面全是空节点（检查节点路径，以及根节点 node_paths 里有没有 panels）。" % index)
		return null
	push_warning("敌人 %d 没有自己的对话框（panels 第 %d 个是空节点或不存在），先用 %s。" % [index, index, fallback.name])
	return fallback


## 这个对话框能不能显示；不能就报警并跳过这一组
func _can_show_on(panel: DialogPanel, enemy_index: int) -> bool:
	if panel == null:
		return false # panel_for_enemy 已经报过警了
	if panel.dialog_label == null:
		push_warning("敌人 %d 的对话框 %s 没有接 dialog_label，这组对白没法显示，已跳过。" % [enemy_index, panel.name])
		return false
	return true


## 把 dialogs 切成一批一批
func _split_batches(dialogs: Array) -> Array:
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


func _next_batch(generation: int = -1) -> void:
	if generation >= 0 and generation != _generation:
		return # 这段对话已经被新的 play / close_all 顶掉了
	_batch_index += 1
	if _batch_index >= _batches.size():
		_pending_panels = 0
		finished.emit()
		return
	var batch: Array = _batches[_batch_index]
	# 先把这一批的对白按对话框归拢：同一个对话框（比如越界回退）里的对白合并成一段，避免同一帧显示两次
	var panel_order: Array[DialogPanel] = []
	var panel_dialogs: Dictionary = {}
	for group: Dictionary in batch:
		var panel := panel_for_enemy(group["enemy_index"])
		if not _can_show_on(panel, group["enemy_index"]):
			continue
		if not panel_dialogs.has(panel):
			var queue: Array[BaseDialog] = []
			panel_dialogs[panel] = queue
			panel_order.append(panel)
		var group_dialogs: Array[BaseDialog] = group["dialogs"]
		(panel_dialogs[panel] as Array[BaseDialog]).append_array(group_dialogs)
	if panel_order.is_empty():
		_next_batch()
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
		_next_batch()
		return
	for panel in shown:
		panel.finished.connect(_on_panel_finished, CONNECT_ONE_SHOT)
	_close_inactive_panels(panel_order)


func _on_panel_finished() -> void:
	if _pending_panels <= 0:
		return # 这一批已经收尾了，多出来的 finished 忽略掉
	_pending_panels -= 1
	if _pending_panels <= 0:
		# 等这一帧的调用栈退干净再开下一批：
		# 面板的 hide()、标签的关输入这些都发生在信号回调“之后”，
		# 立刻在这里开下一批会被它们的收尾盖掉（面板被藏、输入被关）。
		_defer_next_batch(_generation)


func _defer_next_batch(generation: int) -> void:
	_next_batch.bind(generation).call_deferred()


func _close_inactive_panels(active: Array[DialogPanel]) -> void:
	for panel in panels:
		if panel and not active.has(panel):
			panel.close()


func _clear_panel_connections() -> void:
	for panel in panels:
		if panel and panel.finished.is_connected(_on_panel_finished):
			panel.finished.disconnect(_on_panel_finished)
