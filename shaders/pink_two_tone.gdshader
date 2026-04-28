shader_type spatial;
render_mode ambient_light_disabled;

uniform vec4 light_pink : source_color = vec4(1.0, 0.28, 1.0, 1.0);
uniform vec4 dark_pink : source_color = vec4(0.78, 0.08, 0.62, 1.0);
uniform float tone_threshold : hint_range(0.0, 1.0) = 0.42;
uniform float shade_lift : hint_range(0.0, 1.0) = 0.2;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	ALBEDO = light_pink.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float attenuation = mix(1.0, ATTENUATION, shadow_strength);
	float shade = clamp(max(dot(NORMAL, LIGHT), 0.0) * attenuation + shade_lift, 0.0, 1.0);
	DIFFUSE_LIGHT += mix(dark_pink.rgb, light_pink.rgb, step(tone_threshold, shade));
}
