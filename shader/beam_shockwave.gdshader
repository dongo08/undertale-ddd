shader_type canvas_item;
// ============================================================
// 竖向白条 (Vertical Beam) —— 噪声流动质感 + 边缘雾化
//
// 核心思路：用多层噪声制造"流动质感"
//   1. 边缘扰动  —— 噪声让条在横向弯曲、抖动，边缘呈流动的曲线
//   2. 边缘雾化  —— 过渡带宽度随噪声流动，边缘如雾气般翻涌散开
//   3. 条内流动  —— 2D 噪声随时间滚动，形成条内明暗流动
//   4. 纵向条纹  —— 压缩 x 轴的高频噪声，模拟能量束的亮线
//   5. 外部噪声激励 —— 加载一张噪声贴图（noise_tex），从上往下滚动，
//      对条内颜色做明暗激励，形成明显的向下流动感
//
// 用法：
//   挂到铺满视口的 ColorRect / Sprite2D 的 ShaderMaterial 上，
//   UV 即屏幕坐标。条位置用 bar_x（UV.x 归一化 0~1）控制。
//   noise_tex 建议用 Godot 的 NoiseTexture2D（FastNoiseLite，
//   noise_type = Simplex 或 Simplex Smooth，seamless = true）直接生成。
// ============================================================

// ---------- 位置与形状 ----------
uniform float bar_x : hint_range(0.0, 1.0) = 0.5;  // 条中心位置（UV.x 归一化）
uniform float bar_width : hint_range(0.01, 0.5) = 0.07; // 条宽度（UV 空间）
uniform float bar_height : hint_range(0.0, 1.0) = 1.0;  // 条纵向覆盖范围：从顶部延伸多少（1.0 = 全高）
uniform bool auto_scan = false;                     // 是否自动左右往返扫过
uniform float scan_speed : hint_range(0.05, 2.0) = 0.3; // 每秒往返周期数

// ---------- 颜色 ----------
uniform vec4 bar_color : source_color = vec4(1.0);          // 条本体颜色
uniform vec4 glow_color : source_color = vec4(0.5, 0.75, 1.0, 1.0); // 辉光颜色
uniform float glow_width : hint_range(0.02, 0.6) = 0.16;    // 辉光范围
uniform float glow_strength : hint_range(0.0, 1.0) = 0.5;   // 辉光强度
uniform float intensity : hint_range(0.0, 2.0) = 1.0;       // 整体强度

// ---------- 噪声 / 流动 / 雾化 ----------
uniform float flow_speed : hint_range(0.0, 8.0) = 2.0;      // 噪声流动速度
uniform float noise_scale : hint_range(0.5, 20.0) = 6.0;    // 噪声频率
uniform float edge_warp : hint_range(0.0, 0.15) = 0.03;     // 边缘扰动幅度
uniform float fog_width : hint_range(0.0, 0.2) = 0.03;      // 边缘雾化宽度（0 = 硬边）
uniform float inner_flow : hint_range(0.0, 1.0) = 0.4;      // 条内流动强度
uniform float streaks : hint_range(0.0, 1.0) = 0.6;         // 纵向条纹强度

// ---------- 外部噪声激励（从上往下滑动） ----------
uniform sampler2D noise_tex;                                // 噪声贴图（建议 NoiseTexture2D）
uniform bool noise_tex_enabled = true;                      // 是否启用外部噪声激励
uniform float noise_scroll_speed : hint_range(0.0, 4.0) = 0.5; // 向下滚动速度
uniform float noise_uv_scale : hint_range(0.1, 8.0) = 1.0;  // 贴图在条上的平铺次数
uniform float excite_strength : hint_range(0.0, 2.0) = 0.6; // 激励强度（明暗脉动幅度）

// ---------------- 噪声工具 ----------------
// 简易 3D value noise
float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash(i + vec3(0.0, 0.0, 0.0)), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
            mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
        mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
            mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
        f.z);
}

// 4 层分形叠加，产生更丰富的流动细节
float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.0 + vec3(11.3, 7.1, 3.7);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    float t = TIME;
    vec4 base = COLOR; // 初始 COLOR 已含节点 color 与父节点 modulate 链

    // 条中心位置：手动控制，或自动往返扫过
    float cx = bar_x;
    if (auto_scan) {
        cx = 0.5 + 0.5 * sin(t * scan_speed * TAU);
    }

    // ---- 1. 边缘扰动：噪声让条随 y 横向弯曲/抖动 ----
    float wob = fbm(vec3(UV.y * noise_scale, t * flow_speed, 0.0));      // 粗扰动
    float fine = fbm(vec3(UV.y * noise_scale * 4.0, t * flow_speed * 1.6, 1.7)); // 细扰动
    float offset = (wob - 0.5) * 2.0 * edge_warp + (fine - 0.5) * edge_warp * 0.5;

    float d = abs(UV.x - cx + offset);
    float half_w = bar_width * 0.5;

    // ---- 2. 边缘雾化：过渡带宽度随噪声流动，雾气般散开 ----
    float fog = fog_width * (0.6 + 0.8 * fbm(vec3(UV.y * noise_scale * 2.0, t * flow_speed * 1.3, 9.0)));
    float bar = 1.0 - smoothstep(half_w - fog, half_w + fog, d);

    // ---- 3. 纵向范围：条从顶部延伸 bar_height，底部柔和收尾 ----
    float h_tail = 0.01; // 底部收尾渐变宽度
    float range_mask = 1.0 - smoothstep(bar_height - h_tail, bar_height + h_tail, UV.y);

    // ---- 4. 条内流动纹理 + 纵向能量条纹 ----
    float flow = fbm(vec3(UV.x * noise_scale * 1.5, UV.y * noise_scale * 2.5, t * flow_speed));
    float streak = fbm(vec3(UV.y * noise_scale * 3.0, t * flow_speed * 2.2, 5.0));
    streak = smoothstep(0.4, 0.95, streak);

    // ---- 合成 ----
    vec3 col = vec3(0.0);

    // 辉光（仅在条的有效范围内）
    float glow = exp(-d * d / (2.0 * glow_width * glow_width));
    col += glow_color.rgb * glow * glow_strength * intensity * range_mask;

    // 条本体 + 内部流动明暗
    float body_mask = bar * range_mask;
    float body = body_mask * intensity;
    vec3 body_col = bar_color.rgb;
    body_col *= 0.65 + 0.45 * flow * inner_flow + 0.55 * streak * streaks;
    body_col = clamp(body_col, vec3(0.0), vec3(1.0));
    col += body_col * body;

    // ---- 5. 外部噪声激励：噪声贴图从上往下滚动，调制条内颜色 ----
    // nuv.y 用 "UV.y - t" 采样，图案即向下滑动；fract 保证循环平铺
    if (noise_tex_enabled) {
        vec2 nuv = vec2(UV.x * noise_uv_scale, fract(UV.y * noise_uv_scale - t * noise_scroll_speed));
        float n = texture(noise_tex, nuv).r;
        vec3 exc = vec3(1.0 + (n - 0.5) * excite_strength); // 以 0.5 为中点上下激励
        col = mix(col, col * exc, body_mask);               // 只作用于条（含雾化边缘）
    }

    // 响应节点 color 与父节点 modulate：最终输出 = 本效果 × 初始 COLOR
    COLOR.rgb = col * base.rgb;
    COLOR.a = clamp(body + glow * glow_strength * range_mask, 0.0, 1.0) * base.a;
}
