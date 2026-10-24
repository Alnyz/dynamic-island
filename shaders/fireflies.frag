#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 size;
};

// A handful of warm dots drifting sideways and twinkling.
float hash(float n) { return fract(sin(n) * 43758.5453); }

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec3 col = vec3(0.0);
    for (int i = 0; i < 14; ++i) {
        float fi = float(i);
        float speed = 4.0 + 8.0 * hash(fi * 3.1);
        float x = mod(hash(fi) * size.x + time * speed * (hash(fi * 7.7) < 0.5 ? -1.0 : 1.0), size.x);
        float y = size.y * (0.2 + 0.6 * hash(fi * 1.7)) + 3.0 * sin(time * (0.6 + hash(fi * 5.3)) + fi);
        float twinkle = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(time * (1.2 + 2.0 * hash(fi * 9.1)) + fi * 4.0), 3.0);
        float d = length(px - vec2(x, y));
        col += vec3(1.0, 0.86, 0.55) * twinkle * (1.4 * exp(-d * d * 0.7) + 0.4 * exp(-d * d * 0.06));
    }
    float edge = smoothstep(0.0, 18.0, px.x) * smoothstep(size.x, size.x - 18.0, px.x);
    col *= edge;
    float alpha = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
    fragColor = vec4(col, alpha) * qt_Opacity;
}
