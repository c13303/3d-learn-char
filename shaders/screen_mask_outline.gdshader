shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width_px : hint_range(1.0, 4.0) = 1.0;
uniform vec2 viewport_size = vec2(800.0, 450.0);
uniform float coverage_threshold : hint_range(0.0, 1.0) = 0.02;

void fragment() {
	float sample_width = max(1.0, outline_width_px);
	vec2 center_pixel = floor(UV * viewport_size);
	vec2 center_uv = (center_pixel + vec2(0.5, 0.5)) / viewport_size;
	vec4 center_sample = texture(TEXTURE, center_uv);
	float center = step(coverage_threshold, center_sample.a);

	vec2 right_uv = (center_pixel + vec2(0.5 + sample_width, 0.5)) / viewport_size;
	vec2 left_uv = (center_pixel + vec2(0.5 - sample_width, 0.5)) / viewport_size;
	vec2 up_uv = (center_pixel + vec2(0.5, 0.5 + sample_width)) / viewport_size;
	vec2 down_uv = (center_pixel + vec2(0.5, 0.5 - sample_width)) / viewport_size;

	vec4 right_sample = texture(TEXTURE, right_uv);
	vec4 left_sample = texture(TEXTURE, left_uv);
	vec4 up_sample = texture(TEXTURE, up_uv);
	vec4 down_sample = texture(TEXTURE, down_uv);

	float right = step(coverage_threshold, right_sample.a);
	float left = step(coverage_threshold, left_sample.a);
	float up = step(coverage_threshold, up_sample.a);
	float down = step(coverage_threshold, down_sample.a);

	float global_outline = (1.0 - center) * max(max(left, right), max(up, down));

	float right_id_edge = right * step(0.05, distance(center_sample.rgb, right_sample.rgb));
	float left_id_edge = left * step(0.05, distance(center_sample.rgb, left_sample.rgb));
	float up_id_edge = up * step(0.05, distance(center_sample.rgb, up_sample.rgb));
	float down_id_edge = down * step(0.05, distance(center_sample.rgb, down_sample.rgb));
	float joints_side = step(0.9, center_sample.g) * step(center_sample.r, 0.1);
	float internal_outline = center * joints_side * max(max(left_id_edge, right_id_edge), max(up_id_edge, down_id_edge));

	float outline = max(global_outline, internal_outline);
	COLOR = vec4(outline_color.rgb, outline_color.a * outline);
}
