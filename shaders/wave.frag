#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 size;
};

// Three glowing lines that swell in the middle and meet at the ends.
void main() {
    vec2 uv = qt_TexCoord0;
    float x = uv.x * size.x / size.y;
    float env = pow(sin(3.14159 * uv.x), 1.6);
    vec3 cols[3] = vec3[](vec3(0.04, 0.52, 1.0), vec3(0.66, 0.42, 1.0), vec3(0.95, 0.97, 1.0));
    vec3 col = vec3(0.0);
    for (int i = 0; i < 3; ++i) {
        float fi = float(i);
        float y = 0.5 + env * 0.32 * sin(x * (0.9 + 0.35 * fi) + time * (1.4 + 0.5 * fi) + fi * 2.1);
        float d = abs(uv.y - y) * size.y;
        float line = exp(-d * d * (i == 2 ? 1.6 : 0.6));
        col += cols[i] * line * (i == 2 ? 0.8 : 1.0);
    }
    float edge = smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.92, uv.x);
    col *= edge;
    float alpha = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
    fragColor = vec4(col, alpha) * qt_Opacity;
}
