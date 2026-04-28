shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width_px : hint_range(1.0, 4.0) = 1.0;
uniform vec2 viewport_size = vec2(800.0, 450.0);
uniform float coverage_threshold : hint_range(0.0, 1.0) = 0.35;

float mask_at(sampler2D mask_texture, vec2 output_uv) {
	vec2 output_pixel = floor(output_uv * viewport_size);
	vec2 mask_uv = (output_pixel + vec2(0.5, 0.5)) / viewport_size;
	return step(coverage_threshold, texture(mask_texture, mask_uv).a);
}

void fragment() {
	vec2 px = outline_width_px / viewport_size;
	float center = mask_at(TEXTURE, UV);

	float right = mask_at(TEXTURE, UV + vec2(px.x, 0.0));
	float left = mask_at(TEXTURE, UV + vec2(-px.x, 0.0));
	float up = mask_at(TEXTURE, UV + vec2(0.0, px.y));
	float down = mask_at(TEXTURE, UV + vec2(0.0, -px.y));

	float outline = (1.0 - center) * max(max(left, right), max(up, down));
	COLOR = vec4(outline_color.rgb, outline_color.a * outline);
}
