shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.039,0.071,0.961,1.0);
uniform vec2 vanishing_point = vec2(0.5,0.15); // Vanishing point can be outside the canvas UV if needed
uniform float depth_gradient = 5.0;

uniform float v_line_density = 50.0;
uniform float v_line_sin_cutoff : hint_range(-1.0, 1.0, 0.01) = 0.9;

uniform float h_line_density = 50.0;
uniform float h_line_sin_cutoff : hint_range(-1.0, 1.0, 0.01) = 0.9;
uniform float h_line_scroll_rate : hint_range(-0.2, 0.2, 0.0001) = -0.02;

uniform float horizon_y_uv : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float fade_horizon_y_uv : hint_range(0.0, 1.0, 0.01) = 0.75;

void fragment() {
	// Calculate basis change for UV coordinates to represent perpendicular and parallel distance towards 0.5 left of vanishing point
	// If vanishing point always lies on line UV.x = 0.5 then the change of basis is unnecessary and can be removed
	vec2 vanishing_y_direction = normalize(vanishing_point - vec2(0.5,0.0));
	vec2 vanishing_x_direction = vec2(vanishing_y_direction.y, -vanishing_y_direction.x);
	mat2 basis_change = mat2(vanishing_x_direction, vanishing_y_direction);
	
	// Calculate angle of coordinates from vanishing point and of y position according to the depth gradient
	vec2 displacement = basis_change * (UV - vanishing_point);
	float angle = atan(displacement.x / displacement.y);
	float yangle = atan(depth_gradient * displacement.y);
	yangle = mod((yangle + h_line_scroll_rate*TIME),PI) + PI * 0.5;
	
	// Use calculated angles to determine if there should be a vertical and/or horizontal line present at current UV 
	float v_presence = step(v_line_sin_cutoff, sin(v_line_density * angle));
	float h_presence = step(h_line_sin_cutoff, sin(2.0 * h_line_density * yangle));
	
	// Add a colour where there is a line present
	COLOR = vec4(v_presence);
	COLOR += vec4(h_presence);
	COLOR = min(COLOR, vec4(1.0)); // Clamp the colour so that the parts where the lines cross don't appear brighter
	
	// Fade out the plane where it approaches the horizon (remove bellow line if you don't want this)
	COLOR *= smoothstep(horizon_y_uv, fade_horizon_y_uv,UV.y);
	
	// Set plane to correct colour
	COLOR *= line_color;
}