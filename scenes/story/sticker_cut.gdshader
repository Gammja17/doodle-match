shader_type canvas_item;
// 스티커 배경 오려 내기: cut_mask(흰 = 남김)를 알파에 곱함. 마스크는 StickerCut이 만든 저해상도라 선형 필터로 가장자리가 부드럽다

uniform sampler2D cut_mask : filter_linear, hint_default_white;

void fragment() {
	COLOR.a *= texture(cut_mask, UV).r;
}
