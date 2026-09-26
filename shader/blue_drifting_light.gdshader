shader_type canvas_item;
render_mode blend_add, unshaded;

// ============================================================================
//  Blue Drifting Light  —— 背景蓝色浮光
//  只生成“蓝色浮光”图层，不含底下的格子/字符，以 add 方式叠加在已有背景之上。
//  构成：低频流动烟雾(FBM + domain warp)
//        + 斜向条纹带 + 细密流光条纹（“飘动感 / 条纹感”的来源）
//        + 左→右“先亮后暗”的整体明暗 + 顶部/底部提亮 + 角部压暗 + 细微颗粒
//
//  用法：在背景（格子）之上的 CanvasLayer 里放一个铺满屏幕的 ColorRect，
//        把本 shader 建成 ShaderMaterial 赋给它即可；因为是 add 混合，
//        不需要抠图，蓝色浮光会自己浮在格子上。
//  说明：render_mode 为 blend_add；若改成混合模式，请把 alpha_boost 调回 1.0
//        并只用 alpha 控制可见度。
// ============================================================================

group_uniforms Light;
// 浮光颜色：暗处 -> 亮处。还原自参考图（约 #1b3138 -> #2a4a52，#8fbccd 用于过曝高光）
uniform vec4 light_color_low : source_color = vec4(0.055, 0.129, 0.169, 1.0);
uniform vec4 light_color_high : source_color = vec4(0.165, 0.290, 0.322, 1.0);
uniform vec4 light_color_core : source_color = vec4(0.561, 0.737, 0.804, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.05;        // 总亮度
uniform float coverage : hint_range(0.0, 1.0) = 0.58;         // 浮光覆盖率（阈值/对比）
uniform float softness : hint_range(0.01, 1.0) = 0.68;        // 边缘柔和度
uniform float core_amount : hint_range(0.0, 1.0) = 0.28;      // 过曝白心强度
uniform float grain_amount : hint_range(0.0, 0.5) = 0.07;     // 颗粒/噪点
uniform float alpha_boost : hint_range(0.5, 4.0) = 1.8;       // add 混合时被压暗的 alpha 补偿

group_uniforms Flow;
uniform float time_offset = 0.0;                               // 时间偏移（调试/手动推进动画相位）
uniform float scale = 2.0;                                     // 浮光块面大小
uniform float stretch : hint_range(1.0, 12.0) = 5.2;           // 条纹拉长程度（越大条带越细长）
uniform float flow_speed : hint_range(0.0, 2.0) = 0.04;        // 整体流动速度
uniform vec2 drift_dir = vec2(0.65, -0.30);                    // 飘动方向（叠加在拉伸方向上）
uniform float warp_strength : hint_range(0.0, 4.0) = 2.0;      // 扭曲强度（飘动感的主要来源）
uniform float warp_speed : hint_range(0.0, 2.0) = 0.20;
uniform float detail : hint_range(0.0, 1.0) = 0.32;            // 高频细节占比

group_uniforms Streak;
uniform float streak_amount : hint_range(0.0, 1.5) = 0.15;     // 斜向长条强度
uniform float streak_angle : hint_range(-1.0, 1.0) = 0.28;     // 斜率（+ 向右下，- 向右上）
uniform float streak_scale = 3.2;                              // 长条疏密
uniform float line_amount : hint_range(0.0, 1.0) = 0.05;       // 细密流光条纹强度
uniform float line_freq : hint_range(1.0, 200.0) = 56.0;       // 细条纹频率
uniform float line_speed : hint_range(0.0, 3.0) = 0.55;
uniform float line_distort : hint_range(0.0, 6.0) = 1.6;       // 细条纹跟着流动扭曲

group_uniforms Gradient;
uniform float horizontal_amount : hint_range(0.0, 1.0) = 0.35; // 左->右明暗起伏强度（0=整体均匀）
uniform float horizontal_bias : hint_range(-0.4, 0.4) = -0.06; // 亮带左右偏移
uniform float vertical_amount : hint_range(0.0, 0.6) = 0.08;   // 上下提亮
uniform float corner_vignette : hint_range(0.0, 1.0) = 0.10;   // 角部压暗

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
// 细条纹的纵向压缩量（越小条纹越接近垂直，不受 stretch 影响）
const float LINE_SQUASH = 0.35;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, int oct) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= oct) {
			break;
		}
		sum += amp * vnoise(p);
		norm += amp;
		p = p * 2.02 + vec2(17.3, 9.1);
		amp *= 0.5;
	}
	return sum / max(norm, 1e-4);
}

// 斜向拉伸到 uv 域（只定方向，不做旋转，省三角函数）
vec2 flow_uv(vec2 uv) {
	vec2 d = normalize(vec2(1.0, streak_angle));
	return vec2(uv.x * d.x + uv.y * d.y, -uv.x * d.y + uv.y * d.x);
}

vec2 stretch_uv(vec2 uv, float s) {
	return vec2(uv.x * s, uv.y);
}

// 域扭曲：让浮光有飘动/化开的形变
vec2 warp_field(vec2 uv, float t) {
	vec2 q = stretch_uv(flow_uv(uv), stretch);
	vec2 w = vec2(
		fbm(q * scale * 0.9 + vec2(t * warp_speed * 0.6, 0.0), 3),
		fbm(q * scale * 0.9 + vec2(-t * warp_speed * 0.5, 4.7), 3)
	);
	return (w - 0.5) * 2.0;
}

// 斜向条纹带：沿“横跨条带”的方向做 1D 噪声，天然形成长条形
float slanted_streaks(vec2 uv, float t) {
	vec2 d = normalize(vec2(1.0, streak_angle));
	float across = uv.x * d.y - uv.y * d.x;
	float along = uv.x * d.x + uv.y * d.y;
	float phase = across * streak_scale + along * streak_scale * 0.18;
	float n = fbm(vec2(phase, along * 1.2 + t * flow_speed * 2.0), 2);
	return smoothstep(0.36, 0.78, n);
}

float horizontal_gradient(float x, float y) {
	// 参考图亮度剖面：两端暗，中段最亮，右侧再来一个次高峰 -> 先亮后暗的观感
	float t = clamp(x + horizontal_bias, 0.0, 1.0);
	float main = sin(3.14159265 * clamp(t * 1.05, 0.0, 1.0));
	float secondary = sin(3.14159265 * clamp(t, 0.0, 1.0));
	float profile = mix(main, secondary, 0.35);
	float left_fade = smoothstep(0.0, 0.14, x);
	float right_fade = smoothstep(1.0, 0.86, x);
	// 顶部/底部略亮（参考图上下边缘更亮）
	float edge_glow = max(smoothstep(0.32, 0.02, y), smoothstep(0.68, 0.98, y));
	return mix(1.0, profile, horizontal_amount) * left_fade * right_fade
		* (1.0 + edge_glow * vertical_amount);
}

void fragment() {
	float T = TIME + time_offset;
	vec2 uv = UV;
	vec2 flow = drift_dir * (T * flow_speed);
	vec2 p = uv + flow;

	vec2 warp = warp_field(p, T) * warp_strength;

	// 低频主体：拉长成条状的流动烟云
	// 注意：拉伸后的坐标取值可以很大，必须靠域扭曲 + 偏移把噪声的“格子接缝”打散，
	// 否则会出现生硬的斜向分割线。
	vec2 body_uv = p + warp * 0.06;
	float base = fbm(stretch_uv(flow_uv(body_uv), stretch) * scale + warp * 1.35 + vec2(31.7, 12.4), 5);
	float fine = fbm(stretch_uv(flow_uv(p), stretch * 1.7) * scale * 2.6 + warp * 2.1 + 11.3, 3);
	float smoke = mix(base, fine, detail);

	// 斜向长条
	float streak = slanted_streaks(p + warp * 0.05, T);
	smoke = smoke + streak * streak_amount * 0.55;

	// 细密流光条纹（跟着浮光扭曲 -> 飘动的条纹感）
	vec2 luv = stretch_uv(flow_uv(uv), LINE_SQUASH);
	luv += warp * 0.35;
	float lines = sin(luv.x * line_freq * 6.28318 + T * line_speed + warp.x * line_distort);
	lines = 0.5 + 0.5 * lines;
	lines = pow(lines, 6.0);
	smoke = smoke + lines * line_amount * (0.35 + 0.65 * smoke);

	// 整体明暗：从左到右“先亮后暗”
	float shaped = smoke * horizontal_gradient(uv.x, uv.y) * intensity;

	// 阈值/柔化，做出块面感
	float light_field = smoothstep(coverage - softness * 0.5, coverage + softness * 0.5, shaped);

	// 颜色分级：暗 -> 中 -> 亮心
	vec3 col = mix(light_color_low.rgb, light_color_high.rgb, smoothstep(0.0, 0.55, light_field));
	col = mix(col, light_color_core.rgb, smoothstep(0.55, 1.0, light_field) * core_amount);
	col *= light_field * intensity;

	// 角落压暗 + 颗粒
	float vign = 1.0 - corner_vignette * pow(length((uv - vec2(0.5)) * 1.42), 2.0);
	float grain = (hash21(uv * vec2(1024.0, 768.0) + floor(T * 24.0)) - 0.5) * grain_amount;
	float lum = clamp(dot(col, LUMA) * vign + grain * light_field, 0.0, 4.0);
	col *= lum / max(dot(col, LUMA), 1e-4);   // 颗粒只影响亮度，不污染色相

	COLOR = vec4(col, clamp(light_field * alpha_boost, 0.0, 1.0));
}