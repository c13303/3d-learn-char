shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0, 0.45, 1.0, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ink_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.82;
uniform float hatch_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float black_threshold : hint_range(0.0, 1.0) = 0.18;
uniform float shade_lift : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;
uniform float hatch_spacing_px : hint_range(2.0, 12.0) = 2.0;
uniform float hatch_width_px : hint_range(1.0, 8.0) = 1.0;

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float attenuation = mix(1.0, ATTENUATION, shadow_strength);
	float shade = clamp(max(dot(NORMAL, LIGHT), 0.0) * attenuation + shade_lift, 0.0, 1.0);
	float hatch = step(fract(FRAGCOORD.y / hatch_spacing_px), hatch_width_px / hatch_spacing_px);

	vec3 color = base_color.rgb;
	if (shade >= highlight_threshold) {
		color = highlight_color.rgb;
	} else if (shade < black_threshold) {
		color = ink_color.rgb;
	} else if (shade < hatch_threshold) {
		color = mix(base_color.rgb, ink_color.rgb, hatch);
	}

	DIFFUSE_LIGHT += color;
}
