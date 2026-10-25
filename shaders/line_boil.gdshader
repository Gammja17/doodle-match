shader_type canvas_item;
// 손그림 '라인 보일': 낙서 선이 1초에 boil_fps번 다시 그린 것처럼 살짝 흔들린다.
// Sprite2D / TextureRect에 붙인다. 머티리얼 하나를 여러 노드가 같이 써도 위치마다 흔들림이 다르다.
// 그림 가장자리에 strength_px 이상 투명 여백이 있어야 선이 잘리지 않는다.

uniform sampler2D noise_tex : repeat_enable, filter_linear; // shaders/noise/doodle_noise.png
uniform float boil_fps : hint_range(0.0, 24.0) = 6.0;  // 1초에 몇 번 바뀌나 (0이면 멈춤)
uniform float strength_px : hint_range(0.0, 8.0) = 1.5; // 흔들림 세기 (그림 픽셀)
uniform float wobble_px = 20.0; // 흔들림 물결 하나의 길이 (그림 픽셀)

varying float seed;

void vertex() {
	vec2 p = MODEL_MATRIX[3].xy;
	seed = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * boil_fps);
	vec2 jump = fract(vec2(0.618, 0.382) * (frame + seed * 97.0)); // 프레임마다 노이즈 위치를 건너뜀
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	vec2 nuv = px / (wobble_px * 8.0) + jump; // G 채널은 한 장에 물결이 약 8개
	vec2 offset = vec2(texture(noise_tex, nuv).g, texture(noise_tex, nuv + vec2(0.5, 0.25)).g) * 2.0 - 1.0;
	COLOR = texture(TEXTURE, UV + offset * strength_px * TEXTURE_PIXEL_SIZE) * COLOR;
}
