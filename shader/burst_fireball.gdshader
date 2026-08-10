shader_type canvas_item;
// ============================================================
// 白色火球爆裂 (White Fireball Burst) —— Undertale 爆裂风格
//
// 一团白色火球逐渐变小，向外放射柔和的"光刺"（光路）：
//   - 球体核心白热，边缘柔和衰减
//   - 光刺是角度方向的平滑光路：根部粗、尖端细、边缘渐变，
//     不是有棱有角的硬边尖刺（ray_sharpness 可调锐度）
//   - TIME 驱动微光闪烁，增强爆裂感
//
// 由 progress 驱动（0 ~ 1）：
//   0.0 = 最大最亮，1.0 = 完全消失（火球逐渐变小）。
//   可用 Tween / 动画驱动，或直接设固定值。
//
// 用法：
//   挂到铺满视口的 ColorRect / Sprite2D 的 ShaderMaterial 上，
//   UV 即屏幕坐标，火球默认位于屏幕中心（可用 center 调整）。
// ============================================================

// ---------- 进度 ----------
uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 爆裂进度（0 = 最大，1 = 消失）

// ---------- 火球与光刺 ----------
uniform vec2 center = vec2(0.5); // 火球中心（UV 归一化，可用代码设置）
uniform float base_radius : hint_range(0.05, 0.5) = 0.18;  // 初始球半径（UV 归一化）
uniform float ray_count : hint_range(2.0, 32.0) = 12.0;    // 光刺数量基准
uniform float ray_length : hint_range(0.0, 1.0) = 0.35;    // 光刺超出球体的长度
uniform float ray_sharpness : hint_range(1.0, 12.0) = 6.0; // 光刺锐度（越高越分明，仍为柔和渐变）
uniform float ray_taper : hint_range(0.0, 1.0) = 0.8;      // 光刺收窄程度（0 = 等宽，1 = 尖端极细）
uniform float core_glow : hint_range(0.0, 2.0) = 1.2;      // 核心白热强度

// ---------- 雾化 ----------
uniform float fog_amount : hint_range(0.0, 1.0) = 0.5;  // 光刺雾化强度（0 = 清晰边界）
uniform float fog_speed : hint_range(0.0, 4.0) = 1.5;   // 雾气翻涌速度
uniform float mist_brightness : hint_range(0.0, 10.0) = 0.35; // 弥散白雾亮度

// ---------- 颜色 ----------
uniform vec4 core_color : source_color = vec4(1.0);                 // 球体颜色（白）
uniform vec4 ray_color : source_color = vec4(1.0, 0.96, 0.88, 1.0); // 光刺颜色（微暖白）
uniform float flicker : hint_range(0.0, 1.0) = 0.15;                // 微光闪烁强度
uniform float overexpose : hint_range(0.0, 300.0) = 0.8;              // 过曝范围：亮度超过 1 后多快变白（越小越急）

// ---------------- 工具 ----------------
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash3(i + vec3(0.0, 0.0, 0.0)), hash3(i + vec3(1.0, 0.0, 0.0)), f.x),
            mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
        mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x),
            mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
        f.z);
}

float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p = p * 2.0 + vec3(11.3, 7.1, 3.7);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec4 base = COLOR; // 初始 COLOR 已含节点 color 与父节点 modulate 链

    if (progress >= 1.0) { // 完全消失
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        float p = clamp(progress, 0.0, 1.0);
        float scale = 1.0 - p;          // 火球逐渐变小
        float life = 1.0 - p;           // 亮度随进度衰减
        float t = TIME;

        // ---- 极坐标 ----
        vec2 dpos = UV - center;
        float r = length(dpos);
        float ang = atan(dpos.y, dpos.x);

        float ball_r = max(base_radius * scale, 0.0005);

        // ---- 球体核心：中心白热，边缘柔和衰减 ----
        float core = exp(-r / (ball_r * 0.45));
        float ball = smoothstep(ball_r, ball_r * 0.55, r);

        // ---- 放射光刺：角度方向多层正弦叠加 → 不规则柔和光路 ----
        float rays = sin(ang * ray_count)
                   + sin(ang * ray_count * 1.71 + 2.3)
                   + sin(ang * ray_count * 2.93 + 5.1);
        rays = rays * 0.5 / 3.0 + 0.5; // 归一化到 0~1

        // 光刺长度随球缩放；径向平滑衰减 → 尖端细、根部粗
        float ray_end = ball_r + ray_length * scale;

        // 雾化：噪声随时间翻涌，扰动刺的边缘与刺尖 → 雾气般弥散
        float fog_n = fbm(vec3(ang * 4.0, r * 10.0, t * fog_speed));
        float fog_edge = (fog_n - 0.5) * fog_amount * 0.4;                       // 刺边缘阈值扰动
        float fog_tip = (fbm(vec3(r * 14.0, t * fog_speed * 1.3, 3.0)) - 0.5) * fog_amount; // 刺尖扰动

        float ray_fall = smoothstep(ray_end + fog_tip * 0.06, ball_r, r)
                       * smoothstep(0.0, ball_r * 0.3, r); // 球心处由球体覆盖，避免角度斑纹

        // 里面粗外面细：阈值随半径增大而提高，
        // 只有更靠近峰值中心（rays 接近 1）的窄条被点亮 → 尖端收成尖点
        float taper_t = clamp((r - ball_r) / max(ray_length * scale, 0.0005), 0.0, 1.0);
        float thresh = mix(0.42, 0.42 + 0.35 * ray_taper, taper_t) + fog_edge;
        float ray_mask = smoothstep(thresh, thresh + 0.18 / max(ray_sharpness, 1.0), rays);

        // ---- 微光闪烁（随时间步进随机）----
        float flick = 1.0 + flicker * (hash(vec2(floor(t * 24.0), 7.0)) - 0.5) * 2.0 * life;

        // ---- 合成 ----
        vec3 col = vec3(0.0);
        col += ray_color.rgb * ray_mask * ray_fall * life;          // 光刺
        col += core_color.rgb * core * core_glow * life * 0.6;      // 中心白热
        col += core_color.rgb * ball * life;                        // 球体

        // 弥散白雾：雾本身带白色，噪声团块 + 径向渐隐（越远越淡）
        float mist_n = fbm(vec3(ang * 3.0, r * 7.0, t * fog_speed * 0.8));
        float mist = smoothstep(0.35, 0.85, mist_n)                 // 雾的团块
                   * smoothstep(ray_end * 1.8, ball_r * 0.9, r)     // 从球附近延伸到光刺之外
                   * exp(-r * 2.5 / max(ball_r, 0.001))            // 越远越淡
                   * fog_amount * life;
        col += vec3(1.0) * mist * mist_brightness;                  // 白色雾气
        col *= flick;

        // 过曝分析：低亮度保留纯色，亮度超过 1 后平滑过渡到白色
        float l = max(col.r, max(col.g, col.b));
        float over = smoothstep(1.0, 1.0 + overexpose, l);
        vec3 pure = col / max(l, 0.0001);   // 归一化的纯色调
        vec3 lit = pure * min(l, 1.0);      // 未过曝部分（保留原色）

        float alpha = clamp((max(core * 0.8, max(ball, ray_mask * ray_fall)) + mist) * life, 0.0, 1.0);

        // 彩色部分受父节点 modulate 影响；过曝变白的部分保持纯白，无视 modulate
        COLOR = vec4(mix(lit * base.rgb, vec3(1.0), over), alpha * base.a);
    }
}
