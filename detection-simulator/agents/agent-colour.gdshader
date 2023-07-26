shader_type canvas_item;

uniform vec4 new_colour = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	COLOR = texture(TEXTURE, UV); // Get the current colour

	if(COLOR == vec4(1.0, 1.0, 1.0, 1.0)) {
		COLOR = new_colour;
	}
}

