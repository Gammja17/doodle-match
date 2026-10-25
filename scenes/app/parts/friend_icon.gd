class_name FriendIcon
extends Button
## 친구 얼굴 하나: 원형 얼굴 타일(그림이 없으면 속성 색 동그라미 + 이름 첫 글자), 이름, 아래 한 줄(속성 그림·레벨 등).
## id는 f01… 이나 로스터 id 둘 다 (FriendLook이 이어 봄). 편성·앨범·뽑기 결과에서 같이 씀. 누르면 picked(id)

signal picked(id: String)

var id := ""

@onready var _face: TextureRect = %Face
@onready var _initial: Label = %Initial
@onready var _name: Label = %Name
@onready var _note: Label = %Note
@onready var _badge: Label = %Badge
@onready var _attr: TextureRect = %Attr


func _ready() -> void:
	pressed.connect(func(): picked.emit(id))


## note를 비우면 "속성 · Lv" (가진 친구) 또는 속성만
func show_friend(p_id: String, lv := 0, note := "") -> void:
	id = p_id
	var look := FriendLook.shared()
	var attr := look.attr(id)
	var col := FriendLook.attr_color(attr)
	_face.texture = look.face(id)
	_face.self_modulate = Color.WHITE if look.has_face(id) else col.lerp(Color.WHITE, 0.55)
	_initial.visible = not look.has_face(id)
	_initial.text = look.name_of(id).left(1)
	_name.text = look.name_of(id)
	if note == "":
		note = ("%d성 " % look.tier(id) if look.tier(id) > 0 else "") + ("Lv%d" % lv if lv > 0 else FriendLook.attr_name(attr))
	_note.text = note
	_attr.texture = FriendLook.attr_icon(attr)
	_note.add_theme_color_override("font_color", col.darkened(0.25))
	set_badge("")


## 얼굴 오른쪽 위 작은 글자 (NEW!, ▲유리, 단짝 …). 비우면 숨김
func set_badge(text: String) -> void:
	_badge.text = text
	_badge.visible = text != ""


## 얼굴만 (편성 출격 칸): 이름·아래 줄을 숨김
func compact() -> void:
	_name.hide()
	$VBox/NoteRow.hide()
	custom_minimum_size = Vector2(96, 96)
	_face.custom_minimum_size = Vector2(96, 96)


## 못 가진 친구·이미 편성한 친구는 흐리게
func set_dim(on: bool) -> void:
	_face.modulate.a = 0.35 if on else 1.0
	_name.modulate.a = 0.5 if on else 1.0
