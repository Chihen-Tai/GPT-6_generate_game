shader_type spatial;
uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
 vec3 detail=texture(ground_texture,UV).rgb;
 float snow=smoothstep(0.65,0.85,COLOR.b);
 ALBEDO=COLOR.rgb*mix(0.55,1.1,dot(detail,vec3(0.333)));
 ALBEDO=mix(ALBEDO,COLOR.rgb*(0.82+detail.r*0.18),snow);
 ROUGHNESS=0.96;
 NORMAL_MAP=texture(ground_normal,UV).rgb;
 NORMAL_MAP_DEPTH=0.35;
}
