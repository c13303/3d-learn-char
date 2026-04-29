shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec4 id_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

void fragment() {
	ALBEDO = id_color.rgb;
	ALPHA = 1.0;
}
