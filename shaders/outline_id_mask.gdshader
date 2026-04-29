shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec4 id_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool use_id_texture = false;
uniform sampler2D id_texture : filter_nearest, repeat_disable;

void fragment() {
	vec4 id_sample = id_color;
	if (use_id_texture) {
		id_sample = texture(id_texture, UV);
	}

	ALBEDO = id_sample.rgb;
}
