shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec4 water_color : source_color = vec4(0.16, 0.56, 0.58, 0.85);
varying vec3 world_pos;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += sin(world_pos.x * 1.1 + TIME * 0.8) * 0.055 + cos(world_pos.z * 1.3 + TIME) * 0.035;
}
void fragment() {
    float ripple = pow(0.5 + 0.5 * sin(world_pos.x * 2.2 + sin(world_pos.z * 2.0 + TIME) + TIME), 16.0);
    ALBEDO = mix(water_color.rgb, vec3(0.7, 0.92, 0.83), ripple * 0.3);
    ROUGHNESS = 0.2;
    METALLIC = 0.25;
}
