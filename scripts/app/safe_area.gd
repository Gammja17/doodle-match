class_name SafeArea
extends RefCounted
## 노치·펀치홀·아래 제스처 막대를 피함 (폰에서만). 화면마다 배경은 끝까지 깔고, 내용 틀(Screen)만 안전 영역으로 줄임.


## 위·아래로 비워야 할 높이 (뷰포트 좌표). 데스크톱은 0
static func insets(vp: Viewport) -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var k := vp.get_visible_rect().size.y / float(maxi(1, win.y))
	return Vector2(maxi(0, safe.position.y), maxi(0, win.y - safe.end.y)) * k


## 화면 전체를 덮는(anchor 0~1) 내용 틀을 안전 영역 안으로
static func apply(screen: Control) -> void:
	var i := insets(screen.get_viewport())
	screen.offset_top += i.x
	screen.offset_bottom -= i.y
