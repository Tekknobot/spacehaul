shader_type canvas_item;
render_mode unshaded;

// SpaceMECHA deck palette grade.
// The previous implementation replaced luminance bands with fixed swatches,
// which crushed most imported pixel-art values into the darkest colors.
// This version keeps the authored pixel brightness and transfers only the
// palette character (hue/saturation), preserving tile readability.

uniform vec4 palette_0 : source_color = vec4(0.0, 0.0, 0.004, 1.0);
uniform vec4 palette_1 : source_color = vec4(0.0, 0.004, 0.008, 1.0);
uniform vec4 palette_2 : source_color = vec4(0.09, 0.12, 0.16, 1.0);
uniform vec4 palette_3 : source_color = vec4(0.13, 0.16, 0.18, 1.0);
uniform vec4 palette_4 : source_color = vec4(0.21, 0.24, 0.25, 1.0);
uniform vec4 palette_5 : source_color = vec4(0.37, 0.38, 0.38, 1.0);
uniform vec4 palette_accent : source_color = vec4(0.25, 0.28, 0.29, 1.0);

// 0.0 leaves the authored art untouched. Later decks are graded in script.
uniform float grade_strength : hint_range(0.0, 1.0) = 0.82;
uniform float accent_strength : hint_range(0.0, 1.0) = 0.94;

float max3(vec3 c) {
	return max(c.r, max(c.g, c.b));
}

float min3(vec3 c) {
	return min(c.r, min(c.g, c.b));
}

// Use a tint's hue while retaining the source pixel's peak intensity.
// This prevents a dark palette swatch from making an already readable tile
// disappear into black.
vec3 tint_preserve_value(vec3 tint, float source_value) {
	float tint_value = max(max3(tint), 0.0001);
	vec3 hue = tint / tint_value;
	return clamp(hue * source_value, vec3(0.0), vec3(1.0));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;

	if (tex.a <= 0.001 || grade_strength <= 0.001) {
		COLOR = tex;
		return;
	}

	float value = max3(tex.rgb);
	float low = min3(tex.rgb);
	float saturation = (value - low) / max(value, 0.0001);

	// Imported 2D color textures are sampled in linear space. For deciding
	// which palette family to use, convert the value back toward perceptual
	// display space rather than comparing linear values to sRGB-like numbers.
	float perceptual_value = pow(clamp(value, 0.0, 1.0), 1.0 / 2.2);

	// Keep near-black structural pixels near-black. They define the outlines
	// and negative space in the authored tiles.
	if (perceptual_value < 0.035) {
		COLOR = tex;
		return;
	}

	vec3 target;
	float strength = grade_strength;

	// Existing colored signal/hazard/light pixels become the current deck
	// accent while retaining their authored brightness.
	if (saturation > 0.16 && perceptual_value > 0.10) {
		target = tint_preserve_value(palette_accent.rgb, value);
		strength = min(1.0, grade_strength * accent_strength);
	} else {
		// Continuous palette grading avoids hard bands. Shadows use the darker
		// family, mids the body color, and highlights the light family.
		vec3 tint;
		if (perceptual_value < 0.28) {
			float t = smoothstep(0.035, 0.28, perceptual_value);
			tint = mix(palette_2.rgb, palette_3.rgb, t);
		} else if (perceptual_value < 0.58) {
			float t = smoothstep(0.28, 0.58, perceptual_value);
			tint = mix(palette_3.rgb, palette_4.rgb, t);
		} else {
			float t = smoothstep(0.58, 0.95, perceptual_value);
			tint = mix(palette_4.rgb, palette_5.rgb, t);
		}
		target = tint_preserve_value(tint, value);

		// Dark structure gets a little less grading than bright readable detail.
		strength *= smoothstep(0.045, 0.20, perceptual_value);
	}

	vec3 graded = mix(tex.rgb, target, clamp(strength, 0.0, 1.0));
	COLOR = vec4(graded, tex.a);
}
