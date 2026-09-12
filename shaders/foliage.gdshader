shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.35, 0.48, 0.23, 1.0);
varying float height;
void vertex() {
    height = VERTEX.y;
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.x += sin(TIME * 1.5 + p.x * 0.35 + p.z * 0.3) * max(VERTEX.y, 0.0) * 0.13;
}
void fragment() {
    ALBEDO = tint.rgb * (0.75 + clamp(height, 0.0, 1.0) * 0.45);
    ROUGHNESS = 0.95;
}
