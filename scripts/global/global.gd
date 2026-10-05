extends Node
const RAND_UPDATE = preload("uid://chkncv4h7lp48")

var fade_tween:Tween

## 当前难度，战斗里按它取每轮的弹幕脚本。
## 主菜单的 Difficulty 按钮以后改这里就行，现在默认普通。
var difficulty:EnemyRoundSet.Difficulty=EnemyRoundSet.Difficulty.NORMAL

var fade_layer:CanvasLayer

#func _ready() -> void:
	#TranslationServer.set_locale("en")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		if get_tree().root.mode!=Window.MODE_FULLSCREEN:
			get_tree().root.mode=Window.MODE_FULLSCREEN
		else:
			get_tree().root.mode=Window.MODE_WINDOWED

func create_rand_update_effect(node:Node)->Node:
	var rand_update=RAND_UPDATE.instantiate()
	get_tree().root.add_child(rand_update)
	node.reparent(rand_update.screen_viewport)
	return node


func change_scene_to_packed(scene:PackedScene,fade_duration:float=2,fade_color:Color=Color.WHITE):
	if fade_layer:
		fade_layer.queue_free()
	fade_layer=CanvasLayer.new()
	fade_layer.layer=100
	var fade:=ColorRect.new()
	fade.size=Vector2(10000,10000)
	fade.color=fade_color
	get_tree().root.add_child(fade_layer)
	fade_layer.add_child(fade)
	if fade_tween and fade_tween.is_running():
		fade_tween.kill()
	fade_tween=create_tween()
	fade_tween.tween_property(fade,"modulate:a",1,fade_duration/2).from(0)
	# 切场景这一步按物理帧等：放在 tween 回调里的话，落在哪一 tick 不确定，
	# 跨场景的战斗回放就会错开（淡入淡出本身仍然交给 tween 做画面）
	_switch_after_fade(scene,fade,fade_duration)


func _switch_after_fade(scene:PackedScene,fade:ColorRect,fade_duration:float) -> void:
	if !is_zero_approx(fade_duration) :
		await BattleClock.wait_seconds(fade_duration/2.0)
	get_tree().change_scene_to_packed(scene)
	fade_tween=create_tween()
	fade_tween.tween_property(fade,"modulate:a",0,fade_duration/2)
	if !is_zero_approx(fade_duration) :
		await BattleClock.wait_seconds(fade_duration/2.0)
	if is_instance_valid(fade_layer):
		fade_layer.queue_free()
	
