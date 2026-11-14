shader_type canvas_item;
// 加法混合（Add）+ 变色剪影，Sprite2D 用。
//
// 关键坑：canvas_item 的 fragment 一进来，COLOR 已经是「modulate × 贴图」，
// 所以这里绝对不能再 texture(TEXTURE, UV) 乘一次——那会让 alpha 平方，
// 半透明边缘/低透明度的地方直接“消失”，和自带 Add 的表现对不上。
//
// blend_add：颜色直接加到背景上；unshaded：不吃 2D 灯光（不想要可以删掉）。
render_mode blend_add, unshaded;

// 去色强度：0 = 保留原色，1 = 完全灰度（按亮度）
uniform float gray_amount : hint_range(0.0, 1.0) = 1.0;

// 灰度权重：开 = 感知亮度(Rec.709)，关 = 三通道平均
uniform bool perceptual_luma = true;

// 目标颜色：想做白色剪影就保持白色；也可以填别的颜色当“发光色”
uniform vec4 target_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 目标颜色的覆盖强度：0 = 只用去色结果，1 = 整个贴图变成 target_color 的剪影
// （透明度始终来自原贴图，所以剪影形状不变，不会变成白方块）
uniform float color_amount : hint_range(0.0, 1.0) = 0.0;

// 叠加亮度倍数。加法混合很容易过曝，默认 1.0，想要发光就往上调
uniform float brightness : hint_range(0.0, 4.0) = 1.0;

// 整体透明度：<1 更透，>1 更实（最后会 clamp 到 1）
uniform float alpha_scale : hint_range(0.0, 4.0) = 1.0;

// 让叠加亮度跟随原图亮度：0 = 均匀叠加，1 = 原图越亮叠加越强（保留明暗层次）
uniform float luma_weight : hint_range(0.0, 1.0) = 0.0;

// 开关 HDR 2D 的色彩空间补偿。
// 打开 渲染 → 视口 → HDR 2D 后，2D 混合改在“线性空间”做，最后再编码成 sRGB，
// 于是 alpha 当亮度用的低值段会被 gamma 抬亮：软边、淡入、渐隐看起来发硬、发闷。
// 打开这个开关，把 alpha→亮度 的映射按 sRGB 曲线拉回去，观感就和关掉 HDR 2D 时一致。
uniform bool srgb_compensate = false;

// alpha 通道补偿。
// 加法混合的颜色因子是 SRC_ALPHA，alpha 通道的因子也是 SRC_ALPHA，
// 所以写进 framebuffer 的 alpha 其实是 a²：0.5 的软边只剩 0.25 的“覆盖度”。
// 在 SubViewport / CanvasGroup / 读屏 alpha 的场合，边缘会发虚或发硬。
// 打开后输出 alpha = sqrt(a)，颜色贡献不变，最终写进去的 alpha 正好是 a。
uniform bool alpha_compensate = true;

// 手写 sRGB → linear（内置没有 srgb_to_linear，别踩这个坑）
float _srgb_to_linear(float c) {
	return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

void fragment() {
	// COLOR 里已经包含 modulate / self_modulate 和贴图，取一份副本用就行
	vec4 col = COLOR;

	float gray = perceptual_luma
			? dot(col.rgb, vec3(0.2126, 0.7152, 0.0722))
			: (col.r + col.g + col.b) * (1.0 / 3.0);

	vec3 rgb = mix(col.rgb, vec3(gray), gray_amount);
	rgb = mix(rgb, target_color.rgb, color_amount);
	rgb *= brightness * mix(1.0, gray, luma_weight);

	float a = clamp(col.a * alpha_scale, 0.0, 1.0);

	// 期望加到背景上的颜色量（线性空间里）= 颜色 × alpha；
	// 开了 HDR 补偿就换成 srgb_to_linear(a)，让屏幕编码回来正好等于 a。
	vec3 contrib = rgb * (srgb_compensate ? _srgb_to_linear(a) : a);

	// 混合时颜色和 alpha 都会再乘一次输出的 alpha：
	// 把输出 alpha 换成 sqrt(a)，写进 framebuffer 的 alpha 就是 a，
	// 而颜色贡献 = (contrib / out_a) * out_a 仍然不变。
	float out_a = alpha_compensate ? sqrt(a) : a;
	vec3 out_rgb = contrib / max(out_a, 0.0001);

	COLOR = vec4(max(out_rgb, vec3(0.0)), out_a);
}
