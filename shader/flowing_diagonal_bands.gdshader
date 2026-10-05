shader_type canvas_item;
render_mode blend_mix, unshaded;

// ============================================================================
//  Flowing Diagonal Bands —— 流动斜向条纹背景
//
//  效果构成（对应需求）：
//    1) 画面被切成一条条横向长条（band_* 控制条数、条缝、每条色阶）；
//       每一条内部是纯色块：颜色只跟“第几条”有关，同一条在竖向完全相同
//       （color_source = 1，默认）；想要逐像素的噪声渐变就把它调小。
//    2) 两张噪声贴图各自以不同方向 / 速度滚动，再按亮度融合（noise_*），
//       得到“流动的质感”，它同时决定每个长条填充主题色的哪一个色阶；
//    3) 整体是 45° 斜向波浪（wave_*）：波浪处更亮，并且横向条纹在波浪处
//       被向上挤（wave_deform），于是条纹跟着波浪起伏。
//    4) 支持透明：color_low / color_mid / color_high 三个主题色各自带 alpha，
//       按同一套色阶权重插值，所以“暗处更透明、亮处更实”这类效果也能做；
//       opacity 是总开关，最终 alpha = 主题色 alpha × opacity × ColorRect 的 color.a。
//       想要“条缝完全无缝”，把 band_grout 和 band_round 都设为 0 即可。
//
//  用法：
//    - 挂在一个铺满屏幕的 ColorRect 上（材质 = 本 shader 的 ShaderMaterial）；
//    - 把两张噪点图分别拖到 noise_tex_a / noise_tex_b；
//    - 只给了一张也能看，但推荐的用法是给两张（两张的滚动方向 / 速度不同，
//      “流动”的质感主要来自它们的差异）；
//    - 一张贴图都没有也不怕：检测到没贴图 / 贴图是纯白纯黑时，会自动退回
//      内置的程序噪声；也可以把 use_textures 取消勾选，强制全程用程序噪声。
//    - color_low/mid/high 就是“主题色”，换成你自己的配色即可。
//
//  贴图建议：灰度图、Tileable（无缝）、512~1024、噪点柔和一点（值噪声 / Perlin）。
//  如果贴了彩色图，会按亮度（LUMA）取样。
//
//  兼容性：group_uniforms 是 Godot 4.1+ 的语法；更老的引擎把那些行删掉即可，
//  参数会平铺显示，不影响画面。
// ============================================================================

group_uniforms Palette;
// 主题色：暗 -> 中 -> 亮。默认是一套冷蓝，改成自己的主题色即可。
uniform vec4 color_low : source_color = vec4(0.035, 0.086, 0.153, 1.0);
uniform vec4 color_mid : source_color = vec4(0.129, 0.310, 0.478, 1.0);
uniform vec4 color_high : source_color = vec4(0.478, 0.780, 0.898, 1.0);

group_uniforms Bands;
uniform float band_count : hint_range(4.0, 240.0) = 46.0;   // 屏幕横向切成多少条
uniform float band_round : hint_range(0.0, 0.5) = 0.06;     // 条缝柔边（0 = 完全无缝，条内颜色绝对均匀）
uniform float band_grout : hint_range(0.0, 1.0) = 0.12;     // 条缝暗线强度（0 = 完全无缝）
uniform float band_seed : hint_range(0.0, 1.0) = 0.22;      // 每条长条的独立色阶扰动
uniform float band_flat : hint_range(0.0, 1.0) = 0.45;      // 条内明暗是否压平（越大越像纯色块）
uniform float band_slope : hint_range(-0.6, 0.6) = 0.0;     // 长条的倾斜（0=严格水平；配合波浪可再斜一点）
uniform float band_px : hint_range(6.0, 300.0) = 60.0;      // 参考条高（像素）：带长条按屏幕实际像素算
uniform float color_source : hint_range(0.0, 1.0) = 1.0;    // 1 = 条内竖向同色（纯色块），0 = 逐像素噪声

group_uniforms Noise;
uniform bool use_textures = true;                           // 关掉则全用程序噪声（不需要贴图）
uniform sampler2D noise_tex_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D noise_tex_b : hint_default_white, filter_linear, repeat_enable;
uniform vec2 noise_scale = vec2(1.6, 1.0);                  // 噪声在屏幕上的疏密
uniform float noise_contrast : hint_range(0.2, 4.0) = 1.25; // 亮度对比
uniform float noise_blend : hint_range(0.0, 1.0) = 0.55;    // A/B 融合比例（0=全 A，1=全 B）
uniform float noise_b_curve : hint_range(0.2, 4.0) = 1.25;  // 后一张噪声的权重曲线（层次）
uniform float flow_speed_a = 0.05;                           // A 的滚动速度
uniform float flow_speed_b = 0.085;                          // B 的滚动速度
uniform vec2 flow_dir_a = vec2(1.0, -0.20);                  // A 的滚动方向
uniform vec2 flow_dir_b = vec2(-0.65, 0.85);                 // B 的滚动方向
uniform float flow_scale_a = 0.85;                           // A 的滚动幅度
uniform float flow_scale_b = 1.35;                           // B 的滚动幅度

group_uniforms BandShape;
uniform float edge_wobble : hint_range(0.0, 4.0) = 0.18;    // 长条边缘左右摆动（跟着噪声流）
uniform float edge_quant : hint_range(2.0, 512.0) = 64.0;   // 摆动量化：避免长条被平滑噪声糊掉
uniform float stripe_follow : hint_range(0.0, 1.0) = 0.12;  // 噪声亮度再推一下条边位置

group_uniforms Wave;
uniform float wave_angle : hint_range(-180, 180) = 45.0; // 波浪方向（度）。45°=左下往右上的斜向
uniform float wave_len : hint_range(0.1, 6.0) = 1.9;        // 屏幕上放几个波
uniform float wave_speed : hint_range(0.0, 2.0) = 0.12;     // 波浪流动速度
uniform float wave_sharp : hint_range(0.5, 8.0) = 2.1;      // 波浪锐度（越大波带越窄）
uniform float wave_amp : hint_range(0.0, 1.0) = 0.35;       // 波浪亮度加成
uniform float wave_bright : hint_range(0.0, 1.0) = 0.55;    // 波浪处往上提亮的强度
uniform float wave_lighting : hint_range(0.0, 1.0) = 1.0;  // 波浪提亮的总开关（0 = 波浪只推形变、不改亮度）
uniform float wave_deform : hint_range(0.0, 3.0) = 1.20;    // 条纹在波浪处向上形变（条高的比例）
uniform float wave_phase_noise : hint_range(0.0, 2.0) = 0.10; // 噪声让波浪位置游动（0=完全笔直的斜波）

group_uniforms Mood;
uniform float overall_gain : hint_range(0.0, 3.0) = 1.12;   // 总亮度
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // 整体色调叠加
uniform float saturation : hint_range(0.0, 2.0) = 1.0;      // 饱和度
uniform float vignette : hint_range(0.0, 1.0) = 0.22;       // 四角压暗
uniform float grain : hint_range(0.0, 0.3) = 0.022;         // 颗粒
uniform float opacity : hint_range(0.0, 1.0) = 1.0;         // 整体不透明度（配合 ColorRect 的 color.a 一起乘）
uniform float time_offset = 0.0;                            // 手动推动画相位（截图对比用）
uniform float freeze : hint_range(0.0, 1.0) = 0.0;          // 仅调试用：=1 时冻结时间，方便逐像素对比两次渲染

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

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

// 程序噪声兜底：贴图为空 / 关掉贴图时用，保证 shader 永远有画面。
// 每个八度旋转一下格点，避免格纹接缝被看出来。
float proc_noise(vec2 p) {
	const mat2 ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < 4; i++) {
		sum += amp * vnoise(p);
		norm += amp;
		p = ROT * p * 2.03 + vec2(19.1, 7.3);
		amp *= 0.5;
	}
	return sum / max(norm, 1e-4);
}

float proc_flow(vec2 uv, float t) {
	vec2 q = (uv - 0.5) * noise_scale;
	float n = proc_noise(q * 3.1 + vec2(t * 0.35, t * -0.24));
	return clamp((n - 0.5) * noise_contrast + 0.5, 0.0, 1.0);
}

float noise_lum(vec2 uv, float t) {
	vec2 q = (uv - 0.5) * noise_scale;
	if (!use_textures) {
		return proc_flow(uv, t);
	}
	vec2 oa = flow_dir_a * (t * flow_speed_a) * flow_scale_a;
	vec2 ob = flow_dir_b * (t * flow_speed_b) * flow_scale_b;
	// 采样值再乘 0.8：减小纹理的 wrap 接缝在滚动时的可见度
	float a = dot(texture(noise_tex_a, q + oa).rgb, LUMA) * 0.8;
	float b = dot(texture(noise_tex_b, q + ob).rgb, LUMA) * 0.8;
	a = clamp((a - 0.5) * noise_contrast + 0.5, 0.0, 1.0);
	b = pow(clamp((b - 0.5) * noise_contrast + 0.5, 0.0, 1.0), noise_b_curve);
	// 两张贴图都是纯黑 / 没贴图（默认白）时当作没有输入，退回程序噪声，
	// 免得画面死平或者整片过亮。
	float black = float(max(a, b) < 0.03);
	float white = float(min(a, b) > 0.93);
	if (black + white > 1.5) {
		return proc_flow(uv, t);
	}
	return clamp(mix(a, b, noise_blend), 0.0, 1.0);
}

// 斜向波浪：一次算出 (主波, 泛音波)，都是 0..1、1 在波峰。
// 一次返回两个，省掉在 fragment 里把同一个三角函数算两遍。
// phase_off 用来让波浪位置轻微游动（保持相干，不会被噪声打散）。
vec2 wave_field_pair(vec2 uv, float t, float phase_off) {
	float ang = radians(wave_angle);
	vec2 dir = vec2(cos(ang), sin(ang));
	float z = (dot(uv, dir) - 0.5 * (dir.x + dir.y)) * wave_len + phase_off - t * wave_speed;
	// 主频保证波带连贯，叠一点低频让波浪有起伏、不机械
	float w = sin(z * 6.28318) * 0.82 + sin(z * 6.28318 * 0.41 + 2.3) * 0.18;
	float main_wave = pow(clamp(0.5 + 0.5 * w, 0.0, 1.0), wave_sharp);
	// 泛音：同一相位、低频 0.55 倍，形变时混一点进去，波浪更顺
	float z2 = z * 0.55;
	float w2 = sin(z2 * 6.28318) * 0.82 + sin(z2 * 6.28318 * 0.41 + 2.3) * 0.18;
	float soft_wave = pow(clamp(0.5 + 0.5 * w2, 0.0, 1.0), wave_sharp);
	return vec2(main_wave, soft_wave);
}

void fragment() {
	float t = mix(TIME + time_offset, 7.0, freeze);
	vec2 uv = UV;
	float px = max(1.0, 1.0 / max(SCREEN_PIXEL_SIZE.y, 1e-6));   // 屏幕高度（像素）

	float n = noise_lum(uv, t);

	// ---- 波浪 ------------------------------------------------------------
	// 注意：波浪本身要“相干”才看得出是斜向的；所以只让噪声轻微游动它的相位，
	// 而不是让噪声直接改变它的强度（否则会变成一圈圈等高线）。
	float wave_wobble = (n - 0.5) * wave_phase_noise;
	vec2 waves = wave_field_pair(uv, t, wave_wobble);
	float wave = waves.x;
	float wave_shape = waves.y;

	// ---- 长条取样坐标 ----------------------------------------------------
	// 条高按“屏幕像素”定，和分辨率无关；wave_deform 让条纹在波浪处被向上挤，
	// 于是横向长条跟着波浪一起起伏（不是整屏平移）。
	float band_h_uv = band_count / px;
	float deform = mix(wave, wave_shape, 0.35);
	float shift = deform * wave_deform * band_h_uv;
	float stripe_follow_amt = (n - 0.5) * stripe_follow * band_h_uv;
	// 条边左右摆动：把噪声量化后再推条边，条缝就不会是一条条笔直的平行线
	float wob = floor(n * edge_quant) / edge_quant;
	float x_wobble = (wob - 0.5) * edge_wobble * band_h_uv;

	float y = uv.y + shift - stripe_follow_amt + uv.x * band_slope;  // 向上挤（+y 是屏幕下方）
	float raw = y * band_count - x_wobble * band_count;              // x 方向的摆动 = 往下推同样多的条高
	float idx = floor(raw);
	float f = fract(raw);

	// ---- 条内竖向同色 ----------------------------------------------------
	// 让颜色跟着“第几条”走：在条缝中点处采一次噪声，整条用这个值。
	// color_source = 1 -> 条内竖向完全同色（纯色块）；0 -> 逐像素取噪声（有竖向渐变）。
	if (color_source > 0.001) {
		// 从 (idx 中点, 当前 x) 倒推回屏幕 uv，保证颜色跟着条一起被波浪推着走
		float y_c = (idx + 0.5) / band_count;
		vec2 uv_c = vec2(uv.x, y_c - shift + stripe_follow_amt - uv.x * band_slope);
		n = mix(n, noise_lum(uv_c, t), color_source);
	}

	// ---- 切成横向长条 ----------------------------------------------------
	// 条缝有两种做法，按 band_round 自动切：
	//   band_round > 0：用 smoothstep 做柔边，core 到条中心为 1、到条缝为 0；
	//   band_round = 0：完全无缝，core 恒为 1（注意不能写 smoothstep(0,0,f)——
	//                   GLSL 里边缘相等是未定义行为，会返回 0，于是条缝出现黑像素）。
	float core = 1.0;
	bool crisp = band_round <= 0.0005 || band_grout <= 0.0005;
	if (!crisp) {
		float e = clamp(band_round, 0.0, 0.5);
		core = smoothstep(0.0, e, f) * smoothstep(1.0, 1.0 - e, f);
	}
	float seam = mix(1.0, core, band_grout);                     // band_grout=0 -> 恒为 1，绝不压暗

	// ---- 每个长条填充的色阶 ---------------------------------------------
	// 条内是纯色：颜色只跟“第几条”+ 噪声亮度有关，同一往 x 方向完全相同。
	// 所以这里绝不能用 x —— 用了就会在 x 方向出现渐变，破坏“竖向同色”。
	float rnd = hash21(vec2(idx, 3.17));
	float seedless = mix(n, rnd, band_seed);
	float level = pow(core, mix(1.0, 0.25, band_flat));          // 条内提亮 / 压平
	float value = clamp(seedless * level, 0.0, 1.0);
	float lit = clamp(value + wave * wave_amp, 0.0, 1.0);

	// ---- 上色 ------------------------------------------------------------
	// 三个主题色各带自己的 alpha，所以“越亮的色阶越透明/越实”也能做。
	// alpha 的渐变和 rgb 用同一套权重，保证色阶和透明度一一对应。
	float w1 = smoothstep(0.0, 0.55, lit);
	float w2 = smoothstep(0.55, 1.0, lit);
	vec3 col = mix(color_low.rgb, color_mid.rgb, w1);
	col = mix(col, color_high.rgb, w2);
	float ramp_a = mix(mix(color_low.a, color_mid.a, w1), color_high.a, w2);
	// 到这里为止，颜色只跟 (n, 第几条, 波浪强度) 有关：
	// 只要 color_source = 1 且 band_round/band_grout = 0，同一条竖向就是完全相同的纯色块。

	// ---- 照明（逐像素） ---------------------------------------------------
	// 这一段的量都是逐像素的，所以会让“条内竖向绝对同色”出现一点点偏差。
	// 想要绝对纯色：把 wave_lighting / vignette / grain 都调 0。
	col *= seam;                                                 // 条缝（无缝时为 1）
	col *= mix(1.0, 1.0 + wave * wave_bright, wave_lighting);    // 波浪处提亮
	col *= overall_gain;

	// 饱和度 / 色调
	col *= color_tint.rgb;
	float lum = dot(col, LUMA);
	col = mix(vec3(lum), col, saturation);
	col = clamp(col, vec3(0.0), vec3(1.0));

	// 四角压暗 + 颗粒（只作用于颜色，不改变透明度：压暗处不该变透明）
	float vig = 1.0 - vignette * pow(length((uv - vec2(0.5)) * 1.42), 2.0);
	col *= vig;
	float g = (hash21(uv * vec2(1024.0, 768.0) + floor(t * 24.0)) - 0.5) * grain;
	col = clamp(col + g, vec3(0.0), vec3(1.0));

	// ---- 透明度 ----------------------------------------------------------
	// ramp_a = 三个主题色的 alpha 按同一套权重插出来的值（色阶 -> 透明度）。
	// opacity 是总开关，COLOR.a 还带着 ColorRect 的 color.a / modulate.a：
	// 最终的 alpha = 主题色 alpha × opacity × ColorRect.color.a。
	// 注意用透明时最好把 ColorRect 的 color 设成纯白，否则颜色会被 color.rgb 再乘一遍。
	float alpha = clamp(ramp_a * opacity * COLOR.a, 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
