shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.4,0.8,1.0,1.0);
uniform float phase = 0.0;
void fragment() {
    float edge = abs(UV.x*2.0-1.0);
    float soft = pow(max(0.0,1.0-edge),1.5);
    float length_fade = pow(1.0-UV.y,0.65);
    float ripples = 0.75+0.25*sin(UV.y*43.0-phase*22.0+edge*8.0);
    vec3 core = mix(tint.rgb,vec3(1.0),pow(soft,7.0)*0.75);
    ALBEDO = core;
    EMISSION = core*0.5;
    ALPHA = soft*length_fade*ripples*0.9;
}
