shader_type canvas_item;
// 잉크가 번지는 연출 (장애물 '번지는 잉크', 매직 보스 먹칠). spread 0 → 1.
// 기본은 절차적 잉크 얼룩. use_texture_shape를 켜면 그림(TEXTURE)의 알파가 모양이 되고,
// 번짐은 가운데부터 그림을 드러내는 앞머리로만 쓰인다 (VARCO 그림으로 갈아 끼울 때).
// 마르는 잉크처럼 가장자리가 더 진하고, 테두리는 종이 섬유 따라 잔털처럼 번진다.

uniform sampler2D noise_tex : repeat_enable, filter_linear; // shaders/noise/doodle_noise.png
uniform float spread : hint_range(0.0, 1.0) = 1.0;
uniform bool use_texture_shape = false;
uniform vec4 ink_color : source_color = vec4(0.12, 0.14, 0.30, 1.0); // 볼펜 남색
uniform float edge_darken : hint_range(0.0, 1.0) = 0.45; // 마른 테두리 링
uniform float wobble : hint_range(0.0, 0.5) = 0.22;     // 윤곽 울퉁불퉁
uniform float feather : hint_range(0.0, 0.2) = 0.06;    // 섬유 따라 번진 잔털 길이
uniform float flow_speed = 0.02;                        // 살아 있는 잉크처럼 윤곽이 천천히 꿈틀 (0이면 정지)

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 drift = vec2(TIME * flow_speed, 0.0);

	// 방향마다 다른 반지름 + 종이 섬유 잔털
	float lobes = texture(noise_tex, p * 0.18 + drift + 0.5).g * 2.0 - 1.0;
	float fiber = texture(noise_tex, UV * 1.5 + drift * 0.5).r * 2.0 - 1.0;
	float grow = 1.0 - (1.0 - spread) * (1.0 - spread); // 처음엔 빠르게, 끝엔 천천히
	float front = grow * (use_texture_shape ? 1.5 : 0.78) * (1.0 + wobble * lobes);
	float d = r - front + fiber * feather; // 0보다 작으면 잉크 안
	float aa = max(fwidth(r), 0.002);
	float cover = 1.0 - smoothstep(-aa, aa, d);

	float ring = smoothstep(-0.14, -0.01, d); // 테두리 가까울수록 1
	float mottle = texture(noise_tex, UV * 0.7 - drift).g;
	vec4 base = use_texture_shape ? texture(TEXTURE, UV) : ink_color;
	vec3 rgb = base.rgb * (1.0 - edge_darken * ring) * (0.92 + 0.16 * mottle);
	float a = base.a * cover * mix(0.85, 1.0, ring);
	COLOR = vec4(rgb, a) * COLOR;
}
