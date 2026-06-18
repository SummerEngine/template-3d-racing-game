shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 red_paint : source_color = vec4(0.42, 0.025, 0.022, 1.0);
uniform vec4 white_paint : source_color = vec4(0.62, 0.61, 0.55, 1.0);
uniform vec4 grime : source_color = vec4(0.050, 0.045, 0.040, 1.0);
uniform float stripe_scale = 8.0;
uniform float grime_strength : hint_range(0.0, 1.0) = 0.23;

float hash21(vec2 p) {
	p = fract(p * vec2(71.17, 313.91));
	p += dot(p, p + 19.19);
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

void fragment() {
	float stripe = step(0.5, fract(UV.y * stripe_scale));
	float wear = value_noise(UV * vec2(12.0, 38.0));
	vec3 paint = mix(red_paint.rgb, white_paint.rgb, stripe);
	paint = mix(paint, grime.rgb, smoothstep(0.50, 1.0, wear) * grime_strength);

	ALBEDO = paint;
	METALLIC = 0.0;
	SPECULAR = 0.18;
	ROUGHNESS = 0.62 + wear * 0.16;
}
