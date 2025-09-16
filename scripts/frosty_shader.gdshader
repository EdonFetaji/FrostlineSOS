shader_type canvas_item;

/* NEW in Godot 4.3+: declare the screen texture explicitly */
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float freeze : hint_range(0.0, 1.0) = 0.0; // 0 warm → 1 frozen
uniform sampler2D frost_tex : source_color, filter_linear, repeat_enable;
uniform float tiling = 1.6;
uniform vec4 tint : source_color = vec4(0.82, 0.9, 1.0, 1.0);
uniform float desaturate = 0.55;
uniform float edge_bias = 0.45;
uniform float distortion = 0.003;
uniform float time = 0.0;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
    vec3 scene = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;

    vec2 uv = UV * tiling;
    float frost = texture(frost_tex, uv).r;

    float coverage = clamp(freeze, 0.0, 1.0);
    float tex_mask = smoothstep(1.0 - coverage, 1.0, frost);

    float v = length(SCREEN_UV - vec2(0.5));
    float edge = smoothstep(0.35, 0.95, v);
    float mask = clamp(tex_mask + edge * edge_bias * (1.0 - coverage), 0.0, 1.0);

    vec2 flow = texture(frost_tex, uv * 2.0 + vec2(time * 0.02, 0.0)).rg - 0.5;
    vec2 offset_uv = SCREEN_UV + flow * distortion * mask;

    vec3 distorted = texture(SCREEN_TEXTURE, offset_uv).rgb;

    float g = luma(distorted);
    vec3 desat = mix(distorted, vec3(g), desaturate * mask);
    vec3 tinted = mix(desat, tint.rgb, 0.25 * mask);

    COLOR = vec4(mix(scene, tinted, mask), 1.0);
}
