shader_type canvas_item;
render_mode unshaded;

// Runtime environment palette transfer for SpaceMECHA.
// This shader is applied directly to every generated floor and wall Sprite2D.
// It preserves the source pixel luminance while replacing its color family.

uniform vec4 palette_0 : source_color = vec4(0.0, 0.0, 0.004, 1.0);
uniform vec4 palette_1 : source_color = vec4(0.0, 0.004, 0.008, 1.0);
uniform vec4 palette_2 : source_color = vec4(0.09, 0.12, 0.16, 1.0);
uniform vec4 palette_3 : source_color = vec4(0.13, 0.16, 0.18, 1.0);
uniform vec4 palette_4 : source_color = vec4(0.21, 0.24, 0.25, 1.0);
uniform vec4 palette_5 : source_color = vec4(0.37, 0.38, 0.38, 1.0);
uniform vec4 palette_accent : source_color = vec4(0.25, 0.28, 0.29, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0) = 1.0;
uniform float accent_strength : hint_range(0.0, 1.0) = 1.0;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float max3(vec3 c) {
	return max(c.r, max(c.g, c.b));
}

float min3(vec3 c) {
	return min(c.r, min(c.g, c.b));
}

vec3 tint_keep_luma(vec3 tint, float source_luma) {
	float tint_luma = max(luma(tint), 0.0005);
	vec3 normalized_tint = tint / tint_luma;
	return clamp(normalized_tint * source_luma, vec3(0.0), vec3(1.0));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	if (tex.a <= 0.001 || grade_strength <= 0.001) {
		COLOR = tex;
		return;
	}

	float source_luma = luma(tex.rgb);
	float source_value = max3(tex.rgb);
	float source_min = min3(tex.rgb);
	float saturation = (source_value - source_min) / max(source_value, 0.0001);
	float perceptual = pow(clamp(source_luma, 0.0, 1.0), 1.0 / 2.2);

	// Preserve true black and the deepest authored outlines.
	if (perceptual < 0.025) {
		COLOR = tex;
		return;
	}

	vec3 tint;
	float strength = grade_strength;

	// Existing hazard, lamp and signal colors become the selected deck accent.
	if (saturation > 0.18 && perceptual > 0.08) {
		tint = palette_accent.rgb;
		strength *= accent_strength;
	} else if (perceptual < 0.22) {
		float t = smoothstep(0.025, 0.22, perceptual);
		tint = mix(palette_2.rgb, palette_3.rgb, t);
	} else if (perceptual < 0.55) {
		float t = smoothstep(0.22, 0.55, perceptual);
		tint = mix(palette_3.rgb, palette_4.rgb, t);
	} else {
		float t = smoothstep(0.55, 0.92, perceptual);
		tint = mix(palette_4.rgb, palette_5.rgb, t);
	}

	vec3 target = tint_keep_luma(tint, source_luma);

	// Slightly lift readable midtones after colorization without flattening the
	// pixel-art value structure. This keeps later decks vivid rather than muddy.
	float readability = smoothstep(0.045, 0.32, perceptual);
	target *= mix(1.0, 1.12, readability);
	target = clamp(target, vec3(0.0), vec3(1.0));

	COLOR = vec4(mix(tex.rgb, target, clamp(strength, 0.0, 1.0)), tex.a);
}
