shader_type spatial;
uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 uv=world_position.xz/3.0;
 vec3 detail=texture(ground_texture,uv).rgb;
 vec3 grass=vec3(0.42,0.57,0.29);
 float snow=(1.0-smoothstep(-720.0,-360.0,world_position.z))*smoothstep(168.0,384.0,world_position.x);
 float desert=smoothstep(288.0,624.0,world_position.x)*smoothstep(336.0,672.0,world_position.z);
 vec3 tint=mix(mix(grass,vec3(.7,.53,.32),desert),vec3(.85,.91,.94),snow);
 ALBEDO=tint*(.65+detail.r*.55);ROUGHNESS=.96;
 NORMAL_MAP=texture(ground_normal,uv).rgb;NORMAL_MAP_DEPTH=.3;
}
