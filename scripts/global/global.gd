extends Node
const RAND_UPDATE = preload("uid://chkncv4h7lp48")

var fade_tween:Tween

## 当前难度，战斗里按它取每轮的弹幕脚本。
## 主菜单的 Difficulty 按钮以后改这里就行，现在默认普通。
var difficulty:EnemyRoundSet.Difficulty=EnemyRoundSet.Difficulty.NORMAL

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
	var canvas:=CanvasLayer.new()
	canvas.layer=100
	var fade:=ColorRect.new()
	fade.size=Vector2(10000,10000)
	fade.color=fade_color
	get_tree().root.add_child(canvas)
	canvas.add_child(fade)
	if fade_tween and fade_tween.is_running():
		fade_tween.kill()
	fade_tween=create_tween()
	fade_tween.tween_property(fade,"modulate:a",1,fade_duration/2).from(0)
	fade_tween.tween_callback(func():get_tree().change_scene_to_packed(scene))
	fade_tween.tween_property(fade,"modulate:a",0,fade_duration/2)
	fade_tween.tween_callback(canvas.queue_free)
	
