shader_type canvas_item;

uniform bool crt_enabled;
uniform sampler2D viewportNearest : filter_nearest, repeat_disable;
uniform sampler2D viewportLinear : filter_linear, repeat_disable;

uniform float scanLineFac = 0.1;
uniform float scanLineWidth = 0.25;
uniform float nearestFac = 0.0;
uniform float linearFac = 1.3;
uniform bool abberation_enabled = true;
const highp float abberationFac = 0.001;

const vec2 RESOLUTION = vec2(320,180);

void fragment() {
	if(crt_enabled){
		float fy = fract(UV * RESOLUTION).y;
		float scanLine = 0.0;
		float chromaticStrength = abberation_enabled? 1.0 : 0.0;
		if(fy < scanLineWidth || fy > 1.0 - scanLineWidth){
			scanLine = scanLineFac;
		}
		COLOR = vec4(0,0,0,1);
		COLOR.r += texture(viewportLinear, UV - vec2(chromaticStrength * abberationFac, 0.0)).r;
		COLOR.b += texture(viewportLinear, UV + vec2(chromaticStrength * abberationFac, 0.0)).b;
		COLOR.g += texture(viewportLinear, UV).g;
		COLOR = mix(COLOR * linearFac, vec4(0,0,0,1), scanLine);

		COLOR += texture(viewportNearest, UV) * nearestFac;
	}
	else{
		COLOR = texture(viewportNearest,UV);
	}
}