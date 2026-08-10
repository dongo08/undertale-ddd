shader_type canvas_item;

uniform sampler2D current_frame;   // 当前场景渲染结果
uniform sampler2D history_frame;   // 上一帧处理后的输出
uniform float update_prob = 0.075;  // 刷新概率

void fragment() {
    vec3 current = texture(current_frame, UV).rgb;
    vec3 history = texture(history_frame, UV).rgb;

    // 每个像素生成稳定随机数
    float r = fract(sin(dot(UV + TIME, vec2(12.983498, 78.28733))) * 2343758.5453);

    // 以 update_prob 概率使用当前帧，否则保留历史帧
    float mask = step(r, update_prob);

    COLOR.rgb = mix(history, current, mask);
    COLOR.a = 1.0;
}