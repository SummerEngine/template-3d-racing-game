shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 grass_dark : source_color = vec4(0.060, 0.105, 0.074, 1.0);
uniform vec4 grass_sunlit : source_color = vec4(0.165, 0.215, 0.125, 1.0);
uniform vec4 exposed_rock : source_color = vec4(0.155, 0.160, 0.150, 1.0);
uniform vec4 dry_soil : source_color = vec4(0.105, 0.088, 0.064, 1.0);
uniform float patch_scale = 4.2;
uniform float rock_strength : hint_range(0.0, 1.0) = 0.46;

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
	float broken = value_noise(UV * 22.0);
	float rock_mask = smoothstep(0.58, 0.96, broad + broken * 0.26) * rock_strength;
	float soil_mask = smoothstep(0.40, 0.92, value_noise(UV * vec2(11.0, 3.5))) * 0.38;

	vec3 color = mix(grass_dark.rgb, grass_sunlit.rgb, broad * 0.58 + broken * 0.18);
	color = mix(color, dry_soil.rgb, soil_mask);
	color = mix(color, exposed_rock.rgb, rock_mask);

	ALBEDO = color;
	METALLIC = 0.0;
	SPECULAR = 0.12;
	ROUGHNESS = 0.88;
}
