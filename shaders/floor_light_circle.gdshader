shader_type spatial;
render_mode unshaded;

uniform vec3 light_center = vec3(0.0, 0.0, 0.0);
uniform vec4 light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ambient_color : source_color = vec4(0.16, 0.0, 0.12, 1.0);
uniform vec4 ink_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float light_radius : hint_range(0.1, 20.0) = 3.2;
uniform float shade_radius : hint_range(0.1, 20.0) = 6.5;
uniform float hatch_spacing_px : hint_range(2.0, 12.0) = 2.0;
uniform float hatch_width_px : hint_range(1.0, 8.0) = 4.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float distance_to_light = distance(world_position.xz, light_center.xz);
	float in_light = step(distance_to_light, light_radius);
	float in_shade = step(distance_to_light, shade_radius) * (1.0 - in_light);
	float hatch = step(fract(FRAGCOORD.y / hatch_spacing_px), hatch_width_px / hatch_spacing_px);

	vec3 shade_color = mix(light_color.rgb, ink_color.rgb, hatch);
	ALBEDO = mix(ambient_color.rgb, shade_color, in_shade);
	ALBEDO = mix(ALBEDO, light_color.rgb, in_light);
}
