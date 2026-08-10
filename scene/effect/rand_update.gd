extends Node


@export var viewport_a: SubViewport 
@export var viewport_b: SubViewport 
@export var screen_viewport: SubViewport
@export var screen_texture:TextureRect
var material:ShaderMaterial
var frame_index := 0



func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	# 1. 从视频源获取当前帧纹理（可以换成你自己的 VideoStreamTexture / ImageTexture）
	var current_frame_texture:  =screen_viewport.get_texture()
	# 2. 决定目标视口和历史视口（轮流交替）
	var target_viewport: SubViewport
	var history_viewport: SubViewport
	if frame_index % 2 == 0:
		target_viewport = viewport_a
		history_viewport = viewport_b
	else:
		target_viewport = viewport_b
		history_viewport = viewport_a

	material=target_viewport.get_child(0).material
	# 3. 更新 Shader 参数
	material.set_shader_parameter("current_frame", current_frame_texture)
	material.set_shader_parameter("history_frame", history_viewport.get_texture())

	# 4. 只渲染目标视口一次（关键：历史视口本帧不更新，保留上一帧结果）
	target_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	#target_viewport.update()

	# 5. 将目标视口的纹理显示到屏幕上
	screen_texture.texture = target_viewport.get_texture()
	#screen_texture.material.set_shader_parameter("current_frame", current_frame_texture)
	#screen_texture.material.set_shader_parameter("history_frame", screen_texture.texture)

	frame_index += 1
