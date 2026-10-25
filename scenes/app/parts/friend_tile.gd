class_name FriendTile
extends Button
## 친구 카드 한 장 (웹게임 .ccard/.fcard 값 ×1.5): 3:4 색종이 카드(속성 색), 위에 이름, 그 아래 속성·Lv, 아래 64%에 스티커 그림.
## 줄마다 기울기: 1열 −1.5°, 3열 +1.5° (tilt). 편성(가진 친구 목록)과 친구 앨범이 같이 씀.
## 고름(set_on): 금색 고리 + 체크. 못 가짐(set_locked): 그림자 실루엣 + "???". 누르면 picked(id)

signal picked(id: String)

var id := ""


func _ready() -> void:
	pressed.connect(func(): picked.emit(id))
	resized.connect(func(): pivot_offset = size / 2)


## note = 카드 아래 한 줄 (비우면 숨김)
func show_friend(p_id: String, lv := 0, note := "") -> void:
	id = p_id
	var look := FriendLook.shared()
	var attr := look.attr(id)
	var col := FriendLook.attr_color(attr)
	%Paper.self_modulate = col.lerp(Color.WHITE, 0.62)
	var art := look.sticker(id)
	%Art.texture = art if art else look.face(id)
	%Name.text = look.name_of(id)
	%Name.add_theme_color_override("font_color", col.darkened(0.45))
	%Attr.texture = FriendLook.attr_icon(attr)
	%Lv.text = "Lv%d" % lv if lv > 0 else ""
	%Note.text = note
	%Note.visible = note != ""
	set_badge("")
	set_on(false)
	set_locked(false)


## 오른쪽 위 작은 띠 (유리!, 단짝, 강화!, NEW). 비우면 숨김
func set_badge(text: String) -> void:
	%Badge.text = text
	%Badge.visible = text != ""


## 고름: 웹 .ccard.on = 금색 바깥 고리 5px + 금색 체크
func set_on(on: bool) -> void:
	%Check.visible = on
	%Ring.visible = on


## 못 가진 친구: 웹처럼 그림을 검은 실루엣(투명 .15)으로, 이름 "???"
func set_locked(on: bool) -> void:
	%Art.self_modulate = Color(0, 0, 0, 0.15) if on else Color.WHITE
	if on:  # 종이 색은 그대로 두고 조금 바래게
		%Name.text = "???"
		%Paper.self_modulate = %Paper.self_modulate.lerp(Color("e9e3d8"), 0.5)
		%Name.add_theme_color_override("font_color", Color("a99d90"))


## 3열 격자에서 몇 번째 칸인지로 기울기
func tilt(index: int) -> void:
	rotation_degrees = [-1.5, 0.0, 1.5][index % 3]
