shader_type canvas_item;

uniform float tile_size = 64.0;
uniform vec2 color_grid_offset = vec2(-32.0, -32.0);
uniform float hue_shift_degrees = 15.0;
uniform float brightness_shift_points = 15.0;

varying vec2 world_position;


vec2 perlin_fade(vec2 value) {
	return value * value * value * (value * (value * 6.0 - 15.0) + 10.0);
}


vec2 perlin_gradient(vec2 lattice, vec2 seed) {
	float angle = fract(sin(dot(lattice + seed, vec2(127.1, 311.7))) * 43758.5453123) * 6.28318530718;
	return vec2(cos(angle), sin(angle));
}


float perlin_noise(vec2 position, vec2 seed) {
	vec2 lattice = floor(position);
	vec2 offset = fract(position);
	vec2 blend = perlin_fade(offset);
	float bottom_left = dot(perlin_gradient(lattice, seed), offset);
	float bottom_right = dot(perlin_gradient(lattice + vec2(1.0, 0.0), seed), offset - vec2(1.0, 0.0));
	float top_left = dot(perlin_gradient(lattice + vec2(0.0, 1.0), seed), offset - vec2(0.0, 1.0));
	float top_right = dot(perlin_gradient(lattice + vec2(1.0, 1.0), seed), offset - vec2(1.0, 1.0));
	float bottom = mix(bottom_left, bottom_right, blend.x);
	float top = mix(top_left, top_right, blend.x);
	return clamp(mix(bottom, top, blend.y) * 1.41421356237, -1.0, 1.0);
}


vec3 rgb_to_hsv(vec3 color) {
	vec4 k = vec4(0.0, -0.33333333333, 0.66666666667, -1.0);
	vec4 p = mix(vec4(color.bg, k.wz), vec4(color.gb, k.xy), step(color.b, color.g));
	vec4 q = mix(vec4(p.xyw, color.r), vec4(color.r, p.yzx), step(p.x, color.r));
	float delta = q.x - min(q.w, q.y);
	float epsilon = 0.0000000001;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * delta + epsilon)), delta / (q.x + epsilon), q.x);
}


vec3 hsv_to_rgb(vec3 color) {
	vec3 rgb = clamp(abs(mod(color.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return color.z * mix(vec3(1.0), rgb, color.y);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment() {
	vec4 base_color = COLOR;
	// Quantize against the real TileMap boundaries first. Applying the half-tile
	// noise offset before floor() would put a color boundary through every tile.
	vec2 tile_cell = floor(world_position / tile_size);
	vec2 noise_cell = tile_cell + vec2(0.5) + color_grid_offset / tile_size;

	// Both fields share one continuous world grid, while their scales, offsets,
	// and seeds keep the hue and brightness distributions independent.
	float hue_noise = perlin_noise(noise_cell * 0.06055 + vec2(13.7, -8.2), vec2(19.1, 73.4));
	float brightness_noise = perlin_noise(noise_cell * 0.04095 + vec2(-21.6, 5.9), vec2(101.3, 37.8));
	float hue_shift = clamp(hue_noise * hue_shift_degrees, -15.0, 15.0) / 360.0;
	float brightness_shift = clamp(brightness_noise * brightness_shift_points, -15.0, 15.0) / 100.0;

	vec3 hsv = rgb_to_hsv(base_color.rgb);
	hsv.x = fract(hsv.x + hue_shift + 1.0);
	hsv.z = clamp(hsv.z + brightness_shift, 0.0, 1.0);
	COLOR = vec4(hsv_to_rgb(hsv), base_color.a);
}
