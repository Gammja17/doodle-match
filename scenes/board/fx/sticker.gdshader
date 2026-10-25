shader_type canvas_item;
// 판 위 아이템·장애물을 한눈에: 그림 둘레에 두꺼운 테두리(아이템은 흰 스티커) + 바깥 가는 선 + 아래로 떨어진 그림자.
// 테두리는 그림 사각형 안에서만 그려지니 그림 둘레에 투명 여백이 있어야 함 (scenes/board/art는 24px, TileArt.pad)

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_px = 6.0;      // 테두리 두께 (그림 픽셀)
uniform vec4 rim_color : source_color = vec4(0.42, 0.33, 0.27, 0.0);  // 흰 테두리 바깥 가는 선 (밝은 칸 위에서도 스티커 가장자리가 보이게)
uniform float rim_px = 0.0;
uniform vec4 shadow_color : source_color = vec4(0.16, 0.12, 0.2, 0.35);
uniform vec2 shadow_px = vec2(3.0, 5.0);

varying vec4 tint;  // 꼭짓점 색 × modulate (fragment의 COLOR엔 그림 색까지 곱해져 있어 테두리가 지워지므로 따로 받음)

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 base = texture(TEXTURE, UV);
	vec3 rgb = base.rgb;
	// 둘레에 그림이 있으면 1: 바깥 고리 16방향 + 안쪽 고리 8방향 (두꺼워도 이가 빠지지 않게)
	// (TEXTURE는 함수 인자로 넘기면 고도가 컴파일을 못 해서 여기서 바로 셈)
	float edge = outline_px + rim_px;
	vec2 sp = shadow_px * px;
	float ring = base.a;
	float out_a = base.a;
	float sh = texture(TEXTURE, UV - sp).a;
	for (int i = 0; i < 24; i++) {
		bool inner = i >= 16;
		float ang = inner ? float(i - 16) * 0.7853982 + 0.3926991 : float(i) * 0.3926991;
		vec2 d = vec2(cos(ang), sin(ang)) * px * (inner ? 0.55 : 1.0);
		ring = max(ring, texture(TEXTURE, UV + d * outline_px).a);
		out_a = max(out_a, texture(TEXTURE, UV + d * edge).a);
		sh = max(sh, texture(TEXTURE, UV - sp + d * edge).a);
	}
	float rim = rim_px > 0.0 ? out_a * rim_color.a : 0.0;
	sh *= shadow_color.a;
	// 아래에서 위로: 그림자 → 바깥 선 → 테두리 → 그림
	vec4 c = vec4(shadow_color.rgb, sh);
	c = mix(c, vec4(rim_color.rgb, 1.0), rim);
	c.a = max(c.a, rim);
	c = mix(c, vec4(outline_color.rgb, 1.0), ring * outline_color.a);
	c.a = max(c.a, ring * outline_color.a);
	c = mix(c, vec4(rgb, 1.0), base.a);
	c.a = max(c.a, base.a);
	COLOR = c * tint;
}
