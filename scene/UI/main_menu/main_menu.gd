extends Control
const LEVEL_1_SUB_BATTLE = preload("uid://bl6m2ggekg2de")

enum Option{
	START,
	DIFFICULTY,
	MODIFIERS,
	SETTINGS,
	EXIT
}


@onready var bg_particles: GPUParticles2D = $GPUParticles2D
@onready var line_particles: GPUParticles2D = $GPUParticles2D2
@onready var 确定: AudioStreamPlayer = $确定
@onready var 选择: AudioStreamPlayer = $选择
@export var start_label: Button

var option_index:int=0

func _ready() -> void:
	start_label.grab_focus()
	
	

func _on_button_focused():
	选择.play()


func _on_start_label_pressed() -> void:
	确定.play()
	Global.change_scene_to_packed(LEVEL_1_SUB_BATTLE)



func _on_settings_label_pressed() -> void:
	确定.play()


func _on_exit_label_pressed() -> void:
	确定.play()
	get_tree().quit()


func _on_replay_label_pressed() -> void:
	var a=BattleReplay.list_replays()[0]
	print(a)
	BattleReplay.prepare_playback(a["path"])
	Global.change_scene_to_packed(load(a["scene"]))
