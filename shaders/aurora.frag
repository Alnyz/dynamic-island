#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 size;
};

// Soft colour ribbons drifting through the pill, faded at the ends into the black.
void main() {
    vec2 uv = qt_TexCoord0;
    float t = time * 0.35;
    float x = uv.x * size.x / size.y;
    float a = sin(x * 0.9 + t * 1.6 + sin(uv.y * 3.0 + t) * 0.8);
    float b = sin(x * 0.5 - t * 1.1 + cos(uv.y * 2.0 - t * 0.7) * 1.2);
    vec3 col = mix(vec3(0.04, 0.52, 1.0), vec3(0.62, 0.38, 0.98), 0.5 + 0.5 * a);
    col = mix(col, vec3(0.20, 0.88, 0.76), smoothstep(0.2, 1.0, b));
    float centre = 0.5 + 0.16 * sin(x * 0.8 + t * 1.3);
    float band = exp(-pow((uv.y - centre) * 3.4, 2.0));
    float edge = smoothstep(0.0, 0.22, uv.x) * smoothstep(1.0, 0.78, uv.x);
    float alpha = band * edge * 0.9;
    fragColor = vec4(col * alpha, alpha) * qt_Opacity;
}
