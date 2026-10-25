class_name FurnitureSticker
extends Control
## 방에 놓인 가구 한 개 (그림, 없으면 임시 도형 + 이름표). 꾸미기 중에만 끌 수 있음.
## 자리는 아래쪽 가운데 기준 (px). 끌다 놓으면 dropped, 안 끌고 떼면 tapped.

signal tapped(index: int)
signal dropped(index: int, foot: Vector2)

const DRAG_START := 8.0
const GUILD_ART := preload("res://scenes/guild/guild_art.gd")

var index := -1
var clamp_foot: Callable  # (Vector2) -> Vector2: 이 가구가 갈 수 있는 자리로 맞춤 (RoomView가 줌)
var _press := false
var _moved := false
var _grab := Vector2.ZERO  # 누른 곳 (이 가구 안 좌표)
var _mask: BitMap  # 그림의 불투명한 곳 (그림이 없으면 null → 네모 전체)

@onready var _body: Control = $Body
@onready var _shape: Panel = $Body/Shape
@onready var _front: ColorRect = $Body/Front
@onready var _art: TextureRect = $Body/Art
@onready var _name: Label = $Name


## f: GuildConfig.furn 한 줄, px_per: 천분율 1당 px.
## 그림(f.art)이 있으면 그림: 너비는 f.w, 높이는 그림 비율, 그림 맨 아래가 발밑. 없으면 임시 도형(f.w × f.h) + 이름표
func setup(p_index: int, f: Dictionary, px_per: float, flipped: bool, draggable: bool) -> void:
	index = p_index
	var tex := GUILD_ART.texture(f.get("art", ""))
	_mask = GUILD_ART.mask(f.get("art", "")) if tex else null
	_art.texture = tex
	_art.visible = tex != null
	_shape.visible = tex == null
	_front.visible = tex == null
	_name.visible = tex == null
	if tex:
		size = Vector2(f.w * px_per, f.w * px_per * tex.get_height() / tex.get_width())
	else:
		size = Vector2(f.w, f.h) * px_per
		var sb: StyleBoxFlat = _shape.get_theme_stylebox("panel").duplicate()
		sb.bg_color = Color(f.color)
		_shape.add_theme_stylebox_override("panel", sb)
	_body.pivot_offset = size / 2.0
	_body.scale.x = -1.0 if flipped else 1.0
	_name.text = f.name
	tooltip_text = f.name
	mouse_filter = Control.MOUSE_FILTER_STOP if draggable else Control.MOUSE_FILTER_IGNORE


func has_art() -> bool:
	return _art.visible


## 그림이면 투명한 곳은 안 눌림 (뒤에 있는 가구를 잡을 수 있게)
func _has_point(p: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(p):
		return false
	if _mask == null:
		return true
	if _body.scale.x < 0.0:
		p.x = size.x - p.x
	var ms := _mask.get_size()
	var q := Vector2i(clampi(int(p.x / size.x * ms.x), 0, ms.x - 1), clampi(int(p.y / size.y * ms.y), 0, ms.y - 1))
	return _mask.get_bitv(q)


func foot() -> Vector2:
	return position + Vector2(size.x / 2.0, size.y)


func set_foot(p: Vector2) -> void:
	position = p - Vector2(size.x / 2.0, size.y)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = true
			_moved = false
			_grab = e.position
			z_index = 50
		elif _press:
			_press = false
			z_index = 0
			if _moved:
				dropped.emit(index, foot())
			else:
				tapped.emit(index)
		accept_event()
	elif e is InputEventMouseMotion and _press:
		if not _moved and (e.position - _grab).length() < DRAG_START:
			return
		_moved = true
		var p: Vector2 = position + e.position - _grab + Vector2(size.x / 2.0, size.y)  # 손가락을 따라간 발밑
		set_foot(clamp_foot.call(p) if clamp_foot.is_valid() else p)
		accept_event()
