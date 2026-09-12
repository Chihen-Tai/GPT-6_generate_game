shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float thickness = 0.003;
uniform vec4 ink : source_color = vec4(0.10, 0.14, 0.20, 1.0);
void vertex() { VERTEX += NORMAL * thickness; }
void fragment() { ALBEDO = ink.rgb; }
