shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3,0.9,1.0,1.0);
uniform float energy = 1.2;
uniform float fade = 1.0;
uniform float phase = 0.0;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);
    float a = atan(p.y,p.x);
    float outer = 1.0-smoothstep(0.008,0.022,abs(r-0.91));
    float inner = 1.0-smoothstep(0.006,0.018,abs(r-0.73));
    float core = 1.0-smoothstep(0.006,0.018,abs(r-0.33));
    float runes = step(0.60,cos(a*24.0+phase))*step(0.77,r)*step(r,0.86);
    float star = 1.0-smoothstep(0.007,0.025,abs(r-(0.49+0.12*cos(a*6.0+phase))));
    float glow = exp(-abs(r-0.91)*65.0)*0.2;
    float opacity = clamp(outer+inner+core+runes+star+glow,0.0,1.0)*fade;
    ALBEDO = tint.rgb*energy;
    EMISSION = tint.rgb*0.3;
    ALPHA = opacity*tint.a*0.86;
}
