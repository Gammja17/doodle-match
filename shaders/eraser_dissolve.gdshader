shader_type canvas_item;
// 지우개로 지워지듯 사라지는 연출 (블럭이 깨질 때). progress 0 → 1, 1이면 완전히 사라진다.
// 지우개가 rub_dir 쪽으로 쓸고 가며 결 따라 지워지고, 반쯤 지워진 곳은 흐린 흑연 자국,
// 막 지나간 자리에는 분홍 지우개 가루가 남았다가 끝날 때 같이 사라진다.
// 가루는 그림 사각형 안에만 그려진다. 화면 밖으로 튀는 가루가 필요하면 파티클을 따로 붙인다.

uniform sampler2D noise_tex : repeat_enable, filter_linear; // shaders/noise/doodle_noise.png
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rub_dir = vec2(1.0, 0.3);           // 지우개가 쓸고 가는 방향
uniform float rub_bias : hint_range(0.0, 1.0) = 0.45; // 방향대로 지워지는 정도 (0이면 노이즈만)
uniform float edge : hint_range(0.01, 0.5) = 0.18;     // 반쯤 지워진 띠의 폭
uniform float ghost : hint_range(0.0, 0.3) = 0.08;     // 지운 뒤 남는 옅은 자국
uniform vec4 smudge_color : source_color = vec4(0.58, 0.58, 0.62, 1.0); // 번진 흑연
uniform vec4 crumb_color : source_color = vec4(0.86, 0.6, 0.62, 1.0);  // 지우개 가루
uniform float crumb_amount : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	vec2 dir = normalize(rub_dir);
	vec2 side = vec2(-dir.y, dir.x);
	vec2 c = UV - 0.5;

	// 지우개 결: 쓸고 가는 방향으로 길게 늘인 노이즈
	float streak = texture(noise_tex, vec2(dot(c, dir) * 0.4, dot(c, side) * 2.5)).g;
	float sweep = clamp(dot(c, dir) / (abs(dir.x) + abs(dir.y)) + 0.5, 0.0, 1.0);
	float m = mix(streak, sweep, rub_bias); // 클수록 늦게 지워진다

	float t = progress * (1.0 + edge);
	float keep = smoothstep(t - edge, t, m); // 1 = 남음, 0 = 지워짐

	vec3 rgb = mix(mix(ink.rgb, smudge_color.rgb, 0.65), ink.rgb, keep);
	float a = ink.a * max(keep, ghost * (1.0 - progress));

	// 막 지워진 띠 위에 가루
	float behind = t - edge - m; // 지우개가 지나간 뒤 얼마나 됐나
	float band = step(0.0, behind) * (1.0 - smoothstep(0.0, 0.25, behind));
	float grit = texture(noise_tex, vec2(dot(UV, dir) * 1.4, dot(UV, side) * 2.2) + 0.3).b;
	float crumb = smoothstep(0.8, 0.85, grit + crumb_amount * 0.1) * band;
	vec2 inside = smoothstep(vec2(0.0), vec2(0.12), UV) * smoothstep(vec2(0.0), vec2(0.12), 1.0 - UV);
	crumb *= inside.x * inside.y * (1.0 - smoothstep(0.85, 1.0, progress));

	vec4 col = vec4(rgb, a);
	col = mix(col, vec4(crumb_color.rgb, 1.0), crumb * crumb_color.a);
	COLOR = col * COLOR;
}
