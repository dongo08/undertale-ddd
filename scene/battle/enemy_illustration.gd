extends Sprite2D
class_name EnemyIllustration

## 立绘表情表：表情名字 -> 图片。同一个角色可以多个场景共用一份资源。
@export var expressions: ExpressionSet
## 自动跟随该节点的对话表情，填 DialogPanel 或 BattleFrameText。
@export var dialog_source: Node

## 立绘表情变化时发出，方便外部做额外表现（音效、抖动等）。
signal expression_changed(expression: StringName)

func _ready() -> void:
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


## 切换立绘表情；表情名为空或没有配图时不会改变当前立绘。
func change_expression(expression: StringName) -> void:
	if expression.is_empty():
		return
	var illustration := get_expression_texture(expression)
	if illustration == null:
		push_warning("立绘 %s 没有配置表情 \"%s\"。" % [name, expression])
		return
	if texture == illustration:
		return
	texture = illustration
	expression_changed.emit(expression)


## 查这个表情对应的图片，没有配置时返回 null。
func get_expression_texture(expression: StringName) -> Texture2D:
	if expressions == null:
		return null
	return expressions.get_texture(expression)


## 这个表情有没有配图。
func has_expression(expression: StringName) -> bool:
	return expressions != null and expressions.has_expression(expression)
