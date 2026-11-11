shader_type sky;

const float INV_SQRT2 = 0.70710678118;

uniform float g_random_seed = 0.0;
uniform float g_speed = 1.0;
uniform float g_rot_speed = 1.0;
uniform vec4 g_color_a : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 g_color_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform sampler2D tex_sky;
uniform sampler2D tex_draw;
uniform vec2 scale_top_bottom = vec2(0.5, 0.5);
uniform vec2 scale_cylindrical = vec2(3.0, 1.0); // use integer values for U/X value
uniform float horizon_limit : hint_range(0.0, 1.0) = 0.2;

// returns a pseudo random number 
float random(vec2 xy) {
    return fract(sin(dot(xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// taken from godotshaders :)
vec2 rotate(vec2 uv, vec2 pivot, float angle)
{
	mat2 rotation = mat2(vec2(sin(angle), -cos(angle)),
						vec2(cos(angle), sin(angle)));
	
	uv -= pivot;
	uv = uv * rotation;
	uv += pivot;
	return uv;
}

// taken from my tiler shader
vec4 draw_tile(vec4 default_color, vec2 local_uv, vec2 center, float size, float speed, vec4 color)
{	
	vec2 tile_uv_map = (local_uv - center) / size + 0.5;
	tile_uv_map = rotate(tile_uv_map, vec2(0.5), TIME * speed);

    if (
        tile_uv_map.x < 0.0 || tile_uv_map.x > 1.0 ||
        tile_uv_map.y < 0.0 || tile_uv_map.y > 1.0
    ) {
        return default_color;
    }	
		
	vec4 s = texture(tex_draw, tile_uv_map);
	return s * color;
}

// taken from my tiler shader
vec4 draw_layer(
	vec4 default_color, 
	float random_seed,	
	vec2 uv, 
	vec2 grid_size, 
	vec2 speed,
	vec2 cell_offset,
	float draw_size_min,
	float draw_size_max,
	float rot_global_speed,
	float rot_min_speed,
	float rot_max_speed,
	vec4 color_a,
	vec4 color_b
) {
    vec2 grid_uv = (uv * grid_size) - (speed * TIME) + cell_offset;
    vec2 cell_num = floor(grid_uv); // cell indices
    vec2 local_pos = fract(grid_uv); // position inside the cell	
	
	// get draw size for this cell
	vec2 random_offset = random_seed + cell_num;
	float draw_size = mix(draw_size_min, min(draw_size_max, INV_SQRT2), random(random_offset)); 
	float edge_margin = draw_size * INV_SQRT2;		
	float tile_rot_speed = 
		rot_global_speed * 
		(step(0.5, random(cell_num + 1.0)) * 2.0 - 1.0) * // -1 or 1 (rotation direction)
		mix(rot_min_speed, rot_max_speed, random(cell_num + 2.0)); // rotation speed
	
	// get "random" center for this cell
	vec2 draw_center = vec2(
	    mix(edge_margin, 1.0 - edge_margin, random(cell_num + 3.0)),
	    mix(edge_margin, 1.0 - edge_margin, random(cell_num + 4.0))
	);		
	
	// get random color
	vec4 tile_color = vec4(1.0);
	tile_color.rgb = mix(color_a.rgb, color_b.rgb, random(cell_num + 5.0));
	tile_color.a = mix(color_a.a, color_b.a, random(cell_num + 6.0));
	
	return draw_tile(default_color, local_pos, draw_center, draw_size, tile_rot_speed, tile_color);
}

vec2 eyedir_to_cylindrical_uv_mapping(vec3 dir, vec2 scale) {
    float u = -fract(((atan(dir.x, dir.z) + PI) / TAU) * scale.x);
    float v = -dir.y * 0.5 * scale.y;	
	return vec2(u, v);
}

void sky() {
	// get top / bottom uvs
	vec2 uv_top = vec2(EYEDIR.x, -EYEDIR.z);
	vec2 uv_bottom = vec2(EYEDIR.x, EYEDIR.z);
	vec2 uv_tb = (EYEDIR.y >= 0.0) ? uv_top : uv_bottom;
	
	// get cylindrical uvs
	vec2 uv_cyl = eyedir_to_cylindrical_uv_mapping(EYEDIR, scale_cylindrical);
	uv_cyl.y += TIME * 0.025 * g_speed;
	
	// sample tb and cyl
	vec4 col_tb = texture(tex_sky, uv_tb * scale_top_bottom);
	vec4 col_cyl = texture(tex_sky, uv_cyl);
	
	// add tiler layer to cylindrical
	// add tiler layer #1
	vec4 layer1 = draw_layer(
		col_cyl, 
		g_random_seed,	
		uv_cyl, 
		vec2(20.0, 20.0), // grid_size
		vec2(0.0, -0.5) * g_speed,  // speed
		vec2(0.0),		  // cell_offset
		0.1, 0.3, 		  // draw_size_min, draw_size_max
		0.0, 0.0, 0.0,    // rot_global_speed, rot_min_speed, rot_max_speed,
		g_color_a, //  color_a
		g_color_b  //  color_b
	);
	col_cyl.rgb = mix(col_cyl.rgb, layer1.rgb, layer1.a);

	// add tiler layer #2
	vec4 layer2 = draw_layer(
		col_cyl, 
		g_random_seed,	
		uv_cyl, 
		vec2(10.0, 10.0), // grid_size
		vec2(0.0, -1.0) * g_speed,  // speed
		vec2(0.0),		  // cell_offset
		0.1, 0.4, 		  // draw_size_min, draw_size_max
		g_rot_speed, 0.5, 1.0,    // rot_global_speed, rot_min_speed, rot_max_speed,
		g_color_a, //  color_a
		g_color_b  //  color_b
	);
	col_cyl.rgb = mix(col_cyl.rgb, layer2.rgb, layer2.a);
	
	// compute blending mask
	float sky_mask = clamp(1.0 - smoothstep(horizon_limit, 1.0, abs(EYEDIR.y)), 0.0, 1.0);
	
	// blend top/bottom and cylindrical map
	vec3 sky_final = mix(col_tb.rgb, col_cyl.rgb, sky_mask);	
			
	// output final result
	COLOR = sky_final;
}