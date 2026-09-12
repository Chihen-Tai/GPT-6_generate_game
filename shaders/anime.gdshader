shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D color_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
uniform float metal_glint = 0.0;
uniform bool face_material = false;

void fragment() {
    ALBEDO = base_color.rgb;
    if (textured) { ALBEDO *= texture(color_texture, UV).rgb; }
    ROUGHNESS = 0.85;
}

void light() {
    float ndl = dot(NORMAL, LIGHT);
    float band = mix(0.40, 0.72, smoothstep(-0.03, 0.02, ndl));
    band = mix(band, 1.0, smoothstep(0.52, 0.56, ndl));
    if (face_material) { band = mix(0.75, 1.0, smoothstep(-0.15, -0.07, ndl)); }
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band / PI;
    float specular = smoothstep(0.93, 0.95, dot(NORMAL, normalize(LIGHT + VIEW)));
    SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * specular * metal_glint * 0.16;
}
