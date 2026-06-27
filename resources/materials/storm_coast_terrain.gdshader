shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D terrain_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 grass_dark : source_color = vec4(0.038, 0.062, 0.041, 1.0);
uniform vec4 grass_sunlit : source_color = vec4(0.130, 0.160, 0.082, 1.0);
uniform vec4 exposed_rock : source_color = vec4(0.220, 0.205, 0.175, 1.0);
uniform vec4 dry_soil : source_color = vec4(0.135, 0.105, 0.074, 1.0);
uniform float patch_scale = 3.6;
uniform float rock_strength : hint_range(0.0, 1.0) = 0.68;
uniform float soil_strength : hint_range(0.0, 1.0) = 0.54;
uniform float weed_strength : hint_range(0.0, 1.0) = 0.62;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.74;
uniform float terrain_texture_scale = 12.0;
uniform float micro_contrast : hint_range(0.0, 1.0) = 0.16;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 37.7);
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
	float broad = value_noise(UV * patch_scale);
	float broken = value_noise(UV * 18.0);
	float pebble = value_noise(UV * 74.0);
	float streaks = value_noise(UV * vec2(8.0, 2.6));
	float rock_mask = smoothstep(0.50, 0.93, broad + broken * 0.33 + pebble * 0.12) * rock_strength;
	float soil_mask = smoothstep(0.34, 0.88, streaks + broken * 0.24) * soil_strength;
	float weed_mask = smoothstep(0.46, 0.94, 1.0 - broad + value_noise(UV * 31.0) * 0.22) * weed_strength;

	vec3 texture_color = texture(terrain_albedo, UV * terrain_texture_scale).rgb;
	vec3 color = mix(grass_dark.rgb, grass_sunlit.rgb, broad * 0.46 + broken * 0.16);
	color = mix(color, dry_soil.rgb, soil_mask);
	color = mix(color, exposed_rock.rgb, rock_mask);
	color = mix(color, grass_sunlit.rgb * 0.72, weed_mask * 0.34);
	color = mix(color, texture_color, texture_strength);
	color *= 0.92 + (pebble - 0.5) * micro_contrast;

	ALBEDO = color;
	METALLIC = 0.0;
	SPECULAR = 0.08;
	ROUGHNESS = 0.94;
}
