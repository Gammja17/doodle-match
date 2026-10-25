shader_type canvas_item;
// 공책 종이 배경: 따뜻한 미색 + 종이 결 + 옅은 얼룩(커피 링) + (선택) 가로줄·빨간 여백선.
// ColorRect(color 흰색)에 붙인다. 길이 단위는 노드 로컬 픽셀이라 화면 비율이 바뀌어도 줄 간격이 그대로다.
// 노이즈 3번 읽기 + 산수 몇 줄이라 모바일 전체 화면 배경으로 써도 가볍다.

uniform sampler2D noise_tex : repeat_enable, filter_linear; // shaders/noise/doodle_noise.png
// VARCO 종이 텍스처가 생기면 여기 넣는다 (곱하기). 비워 두면 흰색이라 영향 없음.
uniform sampler2D paper_tex : hint_default_white, repeat_enable, filter_linear;
uniform float paper_tex_px = 512.0; // paper_tex 한 장이 덮는 크기(px)

uniform vec4 paper_color : source_color = vec4(0.969, 0.941, 0.878, 1.0);
uniform vec4 stain_color : source_color = vec4(0.80, 0.68, 0.50, 1.0);
uniform float grain_strength : hint_range(0.0, 0.2) = 0.045;
uniform float stain_strength : hint_range(0.0, 1.0) = 0.25;
uniform float noise_px = 256.0; // 노이즈 한 장이 덮는 크기(px)

uniform bool show_lines = true;
uniform float line_spacing = 48.0;
uniform float line_top = 120.0; // 첫 줄의 y
uniform float line_width = 2.0;
uniform vec4 line_color : source_color = vec4(0.56, 0.70, 0.85, 0.7);

uniform bool show_margin = true;
uniform float margin_x = 72.0;
uniform vec4 margin_color : source_color = vec4(0.87, 0.42, 0.45, 0.75);

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

// 선 중심에서 d px 떨어진 곳의 덮임 (화면 배율이 달라도 가장자리가 1px 정도로 부드럽게)
float line_cover(float d, float width) {
	float aa = max(fwidth(d), 0.001);
	return 1.0 - smoothstep(width * 0.5 - aa, width * 0.5 + aa, abs(d));
}

void fragment() {
	vec2 nuv = local_px / noise_px;
	float grain = texture(noise_tex, nuv * vec2(1.0, 3.0)).r; // 세로로 눌린 결
	float blot = texture(noise_tex, nuv * 0.3).g;
	float speck = texture(noise_tex, nuv * 1.7).b;

	vec3 col = paper_color.rgb + (grain - 0.5) * grain_strength;
	// 얼룩: 안쪽은 옅게, 마른 테두리는 조금 진하게
	float stain = smoothstep(0.74, 0.84, blot);
	float ring = stain - smoothstep(0.84, 0.9, blot);
	col = mix(col, stain_color.rgb, (stain * 0.35 + ring * 0.5) * stain_strength);
	col *= 1.0 - smoothstep(0.93, 0.98, speck) * 0.12; // 종이 반점

	// 인쇄 줄은 잉크가 종이 결 따라 고르지 않게 먹는다
	float ink_take = 0.75 + 0.25 * grain;
	if (show_lines && local_px.y > line_top - line_spacing * 0.5) {
		float d = mod(local_px.y - line_top + line_spacing * 0.5, line_spacing) - line_spacing * 0.5;
		col = mix(col, line_color.rgb, line_cover(d, line_width) * line_color.a * ink_take);
	}
	if (show_margin) {
		col = mix(col, margin_color.rgb, line_cover(local_px.x - margin_x, line_width) * margin_color.a * ink_take);
	}

	col *= texture(paper_tex, local_px / paper_tex_px).rgb;
	COLOR = vec4(col * COLOR.rgb, COLOR.a);
}
