extends Node2D
class_name EnemyIllustration

## 立绘表情表：表情名字 -> 图片。同一个角色可以多个场景共用一份资源。
## 图片也可以是 AnimatedTexture（整张多帧动画）—— 它本身就是 Texture2D，现有表直接能用。
@export var expressions: ExpressionSet
## 自动跟随该节点的对话表情，填 DialogPanel 或 BattleFrameText。
@export var dialog_source: Node
## 拆开的部件（身体 / 眼睛 / 嘴 …）：每个部件同样挂本脚本 + 自己那份表情表。
## 不填就自动把子节点里"同样是立绘"的当部件。
@export var parts: Array[Node] = []
## 立绘的视觉中心相对本节点的偏移。血条、伤害数字、攻击特效都对着 get_center() 摆，
## 拆图或换尺寸后只调这一个值，不用去重调 attack_bar 里那一堆偏移。
@export var center_offset: Vector2 = Vector2.ZERO

## 立绘表情变化时发出（自己或任一部件用上了这个表情都算）。
signal expression_changed(expression: StringName)

## 本节点能不能显示图片（纯容器 Node2D 不能，它只负责往下转发）
var _has_texture: bool = false
## 原纹理 -> 本实例专属的动画拷贝
var _own_animations: Dictionary = {}


func _ready() -> void:
	for p in get_property_list():
		if String(p["name"]) == "texture":
			_has_texture = true
			break
	if dialog_source:
		bind_dialog_source(dialog_source)


## 绑定对话来源，之后对话里带的表情会自动切换立绘。
func bind_dialog_source(source: Node) -> void:
	if source == null:
		return
	if not source.has_signal("dialog_started"):
		push_warning("%s 没有 dialog_started 信号，无法自动切换立绘表情。" % source)
		return
	if not source.is_connected(&"dialog_started", _on_dialog_started):
		source.connect(&"dialog_started", _on_dialog_started)


func _on_dialog_started(dialog: BaseDialog) -> void:
	if dialog is ExpressionDialog:
		change_expression((dialog as ExpressionDialog).expression)


## 切换立绘表情，并转发给所有部件（部件各自查自己的表）。
## 返回"这个表情有没有被用上"：自己或任一部件用上都算。
##
## 部件查不到这个表情时保持原样、不报警（部件表天生可以不完整，比如嘴没有 CRY）；
## 只有"叶子节点"（没有部件可转发）查不到时才会警告，那多半是表情名写错了。
func change_expression(expression: StringName) -> bool:
	if expression.is_empty():
		return false
	var illustration := get_expression_texture(expression)
	var part_list := _parts()
	# 只有"立绘装配的根节点"查不到才值得警告；部件查不到属于正常（部件表天生可以不完整）
	if illustration == null and part_list.is_empty() and not (get_parent() is EnemyIllustration):
		push_warning("立绘 %s 没有配置表情 \"%s\"。" % [name, expression])
	if illustration != null and _has_texture:
		var mine := _own_copy(illustration)
		# 用 set/get：本脚本 extends Node2D，容器（不带图片的 Node2D）和 Sprite2D 部件都能挂
		if get("texture") != mine:
			set("texture", mine)
	var applied := illustration != null
	for part in part_list:
		if part.change_expression(expression):
			applied = true
	if applied:
		expression_changed.emit(expression)
	return applied


## 查这个表情对应的图片，没有配置时返回 null。
func get_expression_texture(expression: StringName) -> Texture2D:
	if expressions == null:
		return null
	return expressions.get_texture(expression)


## 这个表情有没有配图（只看本节点自己的表）。
func has_expression(expression: StringName) -> bool:
	return expressions != null and expressions.has_expression(expression)


## 血条、伤害数字、攻击特效对着这个点摆。
func get_center() -> Vector2:
	return global_position + center_offset

func pause():
	for i in parts:
		if i.texture is AnimatedTexture:
			i.texture.pause=true
			
func play():
	for i in parts:
		if i.texture is AnimatedTexture:
			i.texture.pause=false

## 部件列表：显式配的 parts + 子节点里同样是立绘的（去重）
func _parts() -> Array:
	var out: Array = []
	for node in parts:
		if node != null and node.has_method("change_expression") and not out.has(node):
			out.append(node)
	for child in get_children():
		if child != dialog_source and child.has_method("change_expression") and not out.has(child):
			out.append(child)
	return out


## 拿本实例专属的纹理。
## AnimatedTexture 的帧状态在资源上：两个立绘共用同一份会整齐划一地眨眼，
## 所以每个实例拷贝一份，并给一个随机起始帧错开。
## 注意用全局 randi()：立绘是画面，绝不能消耗 BattleRNG 的序列（那会扰动弹幕）。
func _own_copy(source: Texture2D) -> Texture2D:
	if not (source is AnimatedTexture):
		return source
	var copy: AnimatedTexture = _own_animations.get(source) as AnimatedTexture
	if copy == null:
		copy = (source as AnimatedTexture).duplicate() as AnimatedTexture
		copy.current_frame = randi() % maxi(1, copy.frames)
		_own_animations[source] = copy
	return copy
