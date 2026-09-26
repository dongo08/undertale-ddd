extends Resource
class_name ExpressionSet

## 立绘表情表：表情名字（字符串）-> 图片。
##
## 表情是自由字符串，不限于下面这些常量：不同角色可以有自己的表情名
## （例如 "SLEEPY"、"SMUG"），只要表情表里有对应图片就行。
## 空字符串表示“不改变立绘”，对话保持默认值即可。

const NORMAL := &"NORMAL"
const HAPPY := &"HAPPY"
const SURPRISED := &"SURPRISED"
const ANGRY := &"ANGRY"
const WORRIED := &"WORRIED"
const SAD := &"SAD"
const CRY := &"CRY"
const HURT := &"HURT"
const DEFEATED := &"DEFEATED"
const SPARE := &"SPARE"
const EYES_CLOSED := &"EYES_CLOSED"
const DETERMINED := &"DETERMINED"

## 表情名 -> 立绘图片
@export var expressions: Dictionary[String, Texture2D] = {}


## 取表情对应的图片，没有配置时返回 null。
func get_texture(expression: StringName) -> Texture2D:
	if not expressions.has(expression):
		return null
	return expressions[expression]


## 这个表情有没有配图。
func has_expression(expression: StringName) -> bool:
	return expressions.has(expression)
