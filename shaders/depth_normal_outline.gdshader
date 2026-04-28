shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float depth_threshold : hint_range(0.0, 1.0, 0.001) = 0.05;
uniform float reverse_depth_threshold : hint_range(0.0, 1.0, 0.001) = 0.25;
uniform float normal_threshold : hint_range(0.0, 2.0, 0.001) = 0.6;
uniform vec3 normal_edge_bias = vec3(-1.0, -1.0, -1.0);

float get_depth(vec2 screen_uv, mat4 inv_projection_matrix) {
	float depth = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	float depth = get_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 normal = texture(normal_texture, SCREEN_UV).xyz * 2.0 - 1.0;
	vec2 texel_size = 1.0 / VIEWPORT_SIZE.xy;

	vec2 uvs[4];
	uvs[0] = vec2(SCREEN_UV.x, min(1.0 - 0.001, SCREEN_UV.y + texel_size.y));
	uvs[1] = vec2(SCREEN_UV.x, max(0.0, SCREEN_UV.y - texel_size.y));
	uvs[2] = vec2(min(1.0 - 0.001, SCREEN_UV.x + texel_size.x), SCREEN_UV.y);
	uvs[3] = vec2(max(0.0, SCREEN_UV.x - texel_size.x), SCREEN_UV.y);

	float depth_diff = 0.0;
	float reverse_depth_diff = 0.0;
	float normal_sum = 0.0;

	for (int i = 0; i < 4; i++) {
		float neighbor_depth = get_depth(uvs[i], INV_PROJECTION_MATRIX);
		depth_diff += depth - neighbor_depth;
		reverse_depth_diff += neighbor_depth - depth;

		vec3 neighbor_normal = texture(normal_texture, uvs[i]).xyz * 2.0 - 1.0;
		vec3 normal_diff = normal - neighbor_normal;
		float normal_bias_diff = dot(normal_diff, normal_edge_bias);
		float normal_indicator = smoothstep(-0.01, 0.01, normal_bias_diff);
		normal_sum += dot(normal_diff, normal_diff) * normal_indicator;
	}

	float depth_edge = step(depth_threshold, depth_diff);
	float reverse_depth_edge = step(reverse_depth_threshold, reverse_depth_diff);
	float normal_edge = step(normal_threshold, sqrt(normal_sum) - reverse_depth_edge);
	float edge = max(depth_edge, normal_edge);

	vec3 original = texture(screen_texture, SCREEN_UV).rgb;
	ALBEDO = mix(original, outline_color.rgb, edge);
}
