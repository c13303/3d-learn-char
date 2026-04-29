shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width_px : hint_range(1.0, 4.0) = 1.0;
uniform vec2 viewport_size = vec2(800.0, 450.0);
uniform float coverage_threshold : hint_range(0.0, 1.0) = 0.02;

vec3 palette_color(float id) {
	if (id < 0.5) { return vec3(0.0, 1.0, 0.0); }
	if (id < 1.5) { return vec3(0.0, 0.0, 1.0); }
	if (id < 2.5) { return vec3(1.0, 0.0, 0.0); }
	if (id < 3.5) { return vec3(0.0, 1.0, 1.0); }
	if (id < 4.5) { return vec3(1.0, 1.0, 0.0); }
	if (id < 5.5) { return vec3(1.0, 0.0, 1.0); }
	if (id < 6.5) { return vec3(1.0, 0.5, 0.0); }
	if (id < 7.5) { return vec3(0.5, 0.0, 1.0); }
	if (id < 8.5) { return vec3(0.0, 0.5, 1.0); }
	if (id < 9.5) { return vec3(0.5, 1.0, 0.0); }
	if (id < 10.5) { return vec3(1.0, 0.0, 0.5); }
	if (id < 11.5) { return vec3(0.0, 1.0, 0.5); }
	if (id < 12.5) { return vec3(0.5, 0.5, 0.5); }
	if (id < 13.5) { return vec3(1.0, 1.0, 1.0); }
	if (id < 14.5) { return vec3(0.25, 0.25, 1.0); }
	return vec3(1.0, 0.25, 0.25);
}

float nearest_palette_id(vec3 color) {
	float best_id = 0.0;
	float best_distance = 999.0;
	for (int i = 0; i < 16; i++) {
		float id = float(i);
		float color_distance = distance(color, palette_color(id));
		if (color_distance < best_distance) {
			best_distance = color_distance;
			best_id = id;
		}
	}
	return best_id;
}

void fragment() {
	float sample_width = max(1.0, outline_width_px);
	vec2 center_pixel = floor(UV * viewport_size);
	vec2 center_uv = (center_pixel + vec2(0.5, 0.5)) / viewport_size;
	vec4 center_sample = texture(TEXTURE, center_uv);
	float center_occupied = step(coverage_threshold, center_sample.a);
	float center_id = center_occupied * step(0.05, max(max(center_sample.r, center_sample.g), center_sample.b));
	float center_palette_id = nearest_palette_id(center_sample.rgb);

	vec2 right_uv = (center_pixel + vec2(0.5 + sample_width, 0.5)) / viewport_size;
	vec2 left_uv = (center_pixel + vec2(0.5 - sample_width, 0.5)) / viewport_size;
	vec2 up_uv = (center_pixel + vec2(0.5, 0.5 + sample_width)) / viewport_size;
	vec2 down_uv = (center_pixel + vec2(0.5, 0.5 - sample_width)) / viewport_size;

	vec4 right_sample = texture(TEXTURE, right_uv);
	vec4 left_sample = texture(TEXTURE, left_uv);
	vec4 up_sample = texture(TEXTURE, up_uv);
	vec4 down_sample = texture(TEXTURE, down_uv);

	float right = step(coverage_threshold, right_sample.a) * step(0.05, max(max(right_sample.r, right_sample.g), right_sample.b));
	float left = step(coverage_threshold, left_sample.a) * step(0.05, max(max(left_sample.r, left_sample.g), left_sample.b));
	float up = step(coverage_threshold, up_sample.a) * step(0.05, max(max(up_sample.r, up_sample.g), up_sample.b));
	float down = step(coverage_threshold, down_sample.a) * step(0.05, max(max(down_sample.r, down_sample.g), down_sample.b));

	float global_outline = (1.0 - center_occupied) * max(max(left, right), max(up, down));

	float right_id = nearest_palette_id(right_sample.rgb);
	float left_id = nearest_palette_id(left_sample.rgb);
	float up_id = nearest_palette_id(up_sample.rgb);
	float down_id = nearest_palette_id(down_sample.rgb);

	float right_id_edge = right * step(0.5, abs(center_palette_id - right_id)) * step(right_id, center_palette_id);
	float left_id_edge = left * step(0.5, abs(center_palette_id - left_id)) * step(left_id, center_palette_id);
	float up_id_edge = up * step(0.5, abs(center_palette_id - up_id)) * step(up_id, center_palette_id);
	float down_id_edge = down * step(0.5, abs(center_palette_id - down_id)) * step(down_id, center_palette_id);
	float internal_outline = center_id * max(max(left_id_edge, right_id_edge), max(up_id_edge, down_id_edge));

	float outline = max(global_outline, internal_outline);
	COLOR = vec4(outline_color.rgb, outline_color.a * outline);
}
