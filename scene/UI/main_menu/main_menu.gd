extends Control
const LEVEL_1_SUB_BATTLE = preload("uid://bl6m2ggekg2de")

enum Option{
	START,
	DIFFICULTY,
	MODIFIERS,
	SETTINGS,
	EXIT
}
@export var labels:Array[Label]


@onready var bg_particles: GPUParticles2D = $GPUParticles2D
@onready var line_particles: GPUParticles2D = $GPUParticles2D2
@onready var 确定: AudioStreamPlayer = $确定
@onready var 选择: AudioStreamPlayer = $选择

var option_index:int=0

func _ready() -> void:
	_refresh_options()
	
	
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("up") and option_index>0:
		option_index-=1
		选择.play()
		_refresh_options()
	elif event.is_action_pressed("down") and option_index<4:
		option_index+=1
		选择.play()
		_refresh_options()
	if event.is_action_pressed("accept"):
		确定.play()
		if option_index==Option.START:
			Global.change_scene_to_packed(LEVEL_1_SUB_BATTLE,2,Color.BLACK)
		
		
func _refresh_options():
	for i in labels:
		i.modulate=Color.WHITE
	labels[option_index].modulate=Color.YELLOW
	
