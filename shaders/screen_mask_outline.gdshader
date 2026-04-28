shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width_px : hint_range(1.0, 4.0) = 1.0;
uniform vec2 viewport_size = vec2(800.0, 450.0);
uniform float coverage_threshold : hint_range(0.0, 1.0) = 0.02;

void fragment() {
	vec2 px = outline_width_px / viewport_size;
	vec2 center_pixel = floor(UV * viewport_size);
	vec2 center_uv = (center_pixel + vec2(0.5, 0.5)) / viewport_size;
	float center = step(coverage_threshold, texture(TEXTURE, center_uv).a);

	vec2 right_uv = (center_pixel + vec2(1.5, 0.5)) / viewport_size;
	vec2 left_uv = (center_pixel + vec2(-0.5, 0.5)) / viewport_size;
	vec2 up_uv = (center_pixel + vec2(0.5, 1.5)) / viewport_size;
	vec2 down_uv = (center_pixel + vec2(0.5, -0.5)) / viewport_size;

	float right = step(coverage_threshold, texture(TEXTURE, right_uv).a);
	float left = step(coverage_threshold, texture(TEXTURE, left_uv).a);
	float up = step(coverage_threshold, texture(TEXTURE, up_uv).a);
	float down = step(coverage_threshold, texture(TEXTURE, down_uv).a);

	float outline = (1.0 - center) * max(max(left, right), max(up, down));
	COLOR = vec4(outline_color.rgb, outline_color.a * outline);
}
