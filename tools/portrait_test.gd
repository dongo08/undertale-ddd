extends Node

## 临时测试：立绘拆图（部件转发）+ AnimatedTexture 每实例独立 + 锚点
## 注意：AnimatedTexture 的帧推进在渲染侧，headless 里不会自己动，
## 所以这里只验"拷贝成了独立实例 + 起始帧错开 + 没动 BattleRNG"。

const ILLUSTRATION := preload("res://scene/battle/enemy_illustration.gd")

var failures := 0


func _ready() -> void:
	var body_tex := _tex(Color.RED)
	var eyes_normal := _tex(Color.GREEN)
	var eyes_angry := _tex(Color.BLUE)
	var blink := _animated(3)

	# 身体部件：只配了 NORMAL
	var body := _make_portrait("Body", {&"NORMAL": body_tex})
	# 眼睛部件：配了 NORMAL / ANGRY，外加一个多帧动画 BLINK
	var eyes := _make_portrait("Eyes", {&"NORMAL": eyes_normal, &"ANGRY": eyes_angry, &"BLINK": blink})

	# 容器：没有 texture 属性，只负责转发
	var root := Node2D.new()
	root.set_script(ILLUSTRATION)
	add_child(root)
	root.call("set", "center_offset", Vector2(0, -30))
	body.position = Vector2(100, 200)
	eyes.position = Vector2(100, 200)
	root.add_child(body)
	root.add_child(eyes)

	print("--- 部件转发")
	root.call("change_expression", &"NORMAL")
	_expect(body.texture == body_tex and eyes.texture == eyes_normal, "初始 NORMAL：身体和眼睛各拿各的图")
	_expect(root.call("change_expression", &"ANGRY"), "根节点：ANGRY 被用上了（返回 true）")
	_expect(body.texture == body_tex, "身体没配 ANGRY -> 保持原样（不报错、不刷屏）")
	_expect(eyes.texture == eyes_angry, "眼睛换成了 ANGRY 的图")
	_expect(root.get("texture") == null, "容器自己不显示图片（没有 texture 属性也不炸）")

	print("--- 部件表不完整时静默保持")
	_expect(root.call("change_expression", &"CRY") == false, "谁都没配 CRY -> 返回 false")
	_expect(eyes.texture == eyes_angry, "眼睛保持 ANGRY 不变")

	print("--- 锚点")
	root.global_position = Vector2(320, 100)
	_expect(root.call("get_center") == Vector2(320, 70), "get_center() = 位置 + center_offset（%s）" % root.call("get_center"))

	print("--- AnimatedTexture：每个立绘实例一份，起始帧错开")
	# 两个"敌人"共用同一份表情表（资源是共享的）
	var shared := ExpressionSet.new()
	shared.expressions[&"BLINK"] = blink
	var a := _make_portrait("A")
	var b := _make_portrait("B")
	a.set("expressions", shared)
	b.set("expressions", shared)
	add_child(a)
	add_child(b)
	var rng_before := BattleRNG.rng.state
	a.call("change_expression", &"BLINK")
	b.call("change_expression", &"BLINK")
	_expect(a.texture is AnimatedTexture and b.texture is AnimatedTexture, "两边都拿到了 AnimatedTexture")
	_expect(a.texture != b.texture, "两份是各自独立的拷贝（不然会整齐划一地眨眼）")
	_expect(a.texture != blink and b.texture != blink, "都不是共用资源本身")
	_expect((a.texture as AnimatedTexture).frames == 3, "帧数信息带过来了")
	_expect(BattleRNG.rng.state == rng_before, "随机起始帧用的是全局随机，没碰 BattleRNG 序列")

	print("--- 叶子节点查不到表情仍会警告（配置写错时能发现）")
	var lonely := _make_portrait("Lonely", {&"NORMAL": body_tex})
	add_child(lonely)
	_expect(lonely.call("change_expression", &"ANGEY") == false, "没这个表情 -> 返回 false（下面那条 WARNING 就是它报的）")

	print("=== %s ===" % ("全部通过" if failures == 0 else "有 %d 处问题" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _make_portrait(node_name: String, table: Variant = null) -> Sprite2D:
	var node := Sprite2D.new()
	node.name = node_name
	node.set_script(ILLUSTRATION)
	if table != null:
		var set := ExpressionSet.new()
		for key in table:
			set.expressions[key] = table[key]
		node.set("expressions", set)
	return node


func _tex(color: Color) -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _animated(frames: int) -> AnimatedTexture:
	var anim := AnimatedTexture.new()
	anim.frames = frames
	for i in frames:
		anim.set_frame_texture(i, _tex(Color(i / float(frames), 0, 0)))
	return anim


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  [通过] ", message)
		return
	failures += 1
	push_error(message)
	print("  [失败] ", message)
