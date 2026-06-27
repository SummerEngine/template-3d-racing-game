shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 asphalt_dark : source_color = vec4(0.010, 0.011, 0.011, 1.0);
uniform vec4 asphalt_mid : source_color = vec4(0.045, 0.047, 0.046, 1.0);
uniform vec4 aggregate_color : source_color = vec4(0.105, 0.107, 0.102, 1.0);
uniform vec4 rubber_color : source_color = vec4(0.006, 0.006, 0.006, 1.0);
uniform sampler2D asphalt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D micro_reflection_map : filter_linear_mipmap, repeat_enable;
uniform float asphalt_texture_scale : hint_range(0.25, 16.0) = 6.5;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.78;
uniform float wetness : hint_range(0.0, 1.0) = 0.48;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.72;
uniform float rubber_line_strength : hint_range(0.0, 1.0) = 0.26;
uniform float reflection_bias : hint_range(0.0, 1.0) = 0.44;
uniform float sun_sheen_strength : hint_range(0.0, 1.0) = 0.38;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float tire_band(float x, float center, float width) {
	return 1.0 - smoothstep(width * 0.45, width, abs(fract(x) - center));
}

void fragment() {
	vec2 uv = UV;
	float fine = value_noise(uv * 92.0);
	float coarse = value_noise(uv * vec2(7.0, 3.2));
	float streak = value_noise(vec2(uv.x * 18.0, uv.y * 1.45));
	float aggregate = smoothstep(0.72, 1.0, value_noise(uv * 155.0));
	vec2 texture_uv = uv * asphalt_texture_scale;
	vec3 asphalt_tex = texture(asphalt_albedo, texture_uv).rgb;
	float reflection_map = texture(micro_reflection_map, texture_uv * 1.35 + vec2(coarse * 0.025, fine * 0.018)).r;
	float reflective_grain = smoothstep(0.58, 0.93, reflection_map) * grain_strength;

	vec3 color = mix(asphalt_dark.rgb, asphalt_mid.rgb, coarse * 0.58 + fine * 0.18);
	asphalt_tex = pow(asphalt_tex, vec3(1.25)) * 0.48;
	color = mix(color, asphalt_tex, texture_strength);
	color = mix(color, aggregate_color.rgb, aggregate * grain_strength * 0.24);

	float rubber_a = tire_band(uv.x, 0.28, 0.105);
	float rubber_b = tire_band(uv.x, 0.72, 0.105);
	float longitudinal_breakup = smoothstep(0.18, 0.92, streak);
	float rubber = max(rubber_a, rubber_b) * longitudinal_breakup * rubber_line_strength;
	color = mix(color, rubber_color.rgb, rubber);

	float water_sheen = wetness * (0.48 + fine * 0.18 + coarse * 0.18 + reflective_grain * 0.34);
	float sun_sheen = sun_sheen_strength * reflective_grain * (1.0 - rubber * 0.55);
	ALBEDO = color;
	METALLIC = 0.0;
	SPECULAR = clamp(0.28 + reflection_bias * 0.42 + sun_sheen * 0.24, 0.0, 0.78);
	ROUGHNESS = clamp(mix(0.78, 0.34, water_sheen) - sun_sheen * 0.11 + rubber * 0.06, 0.28, 0.86);
}
