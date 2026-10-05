extends Node

## 临时探针：AnimatedTexture 的帧数上限 + 真的会动吗

func _ready() -> void:
	print("--- 帧数上限")
	var tex := AnimatedTexture.new()
	for n in [1, 2, 8, 64, 200, 255, 256, 257, 300]:
		tex.frames = n
		print("  设 %4d -> 读回 %4d" % [n, tex.frames])

	print("--- 真的会自己动吗（3 帧，speed_scale=60）")
	var anim := AnimatedTexture.new()
	anim.frames = 3
	anim.speed_scale = 60.0     # 每帧 1 秒 / 60 ≈ 每 1/60 秒一帧
	for i in 3:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(i / 2.0, 0, 0))
		anim.set_frame_texture(i, ImageTexture.create_from_image(img))
	var sprite := Sprite2D.new()
	sprite.texture = anim
	add_child(sprite)
	var seen := []
	for i in 12:
		await get_tree().process_frame
		if not seen.has(anim.current_frame):
			seen.append(anim.current_frame)
	print("  12 个渲染帧里出现过的帧号：", seen)
	print("  one_shot / pause / speed_scale 可读：", anim.one_shot, anim.pause, anim.speed_scale)
	get_tree().quit(0)
