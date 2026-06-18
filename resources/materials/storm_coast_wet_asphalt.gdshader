shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 asphalt_dark : source_color = vec4(0.010, 0.011, 0.011, 1.0);
uniform vec4 asphalt_mid : source_color = vec4(0.045, 0.047, 0.046, 1.0);
uniform vec4 aggregate_color : source_color = vec4(0.105, 0.107, 0.102, 1.0);
uniform vec4 rubber_color : source_color = vec4(0.006, 0.006, 0.006, 1.0);
uniform float wetness : hint_range(0.0, 1.0) = 0.28;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.42;
uniform float rubber_line_strength : hint_range(0.0, 1.0) = 0.36;
uniform float reflection_bias : hint_range(0.0, 1.0) = 0.18;

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

	vec3 color = mix(asphalt_dark.rgb, asphalt_mid.rgb, coarse * 0.58 + fine * 0.18);
	color = mix(color, aggregate_color.rgb, aggregate * grain_strength * 0.24);

	float rubber_a = tire_band(uv.x, 0.28, 0.105);
	float rubber_b = tire_band(uv.x, 0.72, 0.105);
	float longitudinal_breakup = smoothstep(0.18, 0.92, streak);
	float rubber = max(rubber_a, rubber_b) * longitudinal_breakup * rubber_line_strength;
	color = mix(color, rubber_color.rgb, rubber);

	float water_sheen = wetness * (0.55 + fine * 0.22 + coarse * 0.23);
	ALBEDO = color;
	METALLIC = 0.0;
	SPECULAR = mix(0.22, 0.46, reflection_bias);
	ROUGHNESS = clamp(mix(0.86, 0.46, water_sheen) - rubber * 0.035, 0.36, 0.92);
}
