class_name StoryActor
extends Control
## 대화 무대의 캐릭터 하나: 스티커 그림(없으면 포스트잇 이름표)이 톡 붙고, 표정 표시·흔들기·폴짝·떼기.
## 움직임은 Body만 움직여서 자리(슬롯) 배치는 그대로 둔다.

const Cut := preload("res://scripts/story/sticker_cut.gd")
## 표정 → 스티커 옆에 손글씨로 붙는 표시 (표정 그림이 따로 있으면 그림도 바뀜)
const MARKS := {
	normal = "", happy = "♪", angry = "부글부글", sad = "…", surprised = "!?",
	scared = "덜덜", tired = "휴우", shy = "///", think = "?",
}
const MARK_COLOR := {
	angry = Color(0.78, 0.18, 0.15), sad = Color(0.25, 0.4, 0.75), scared = Color(0.35, 0.35, 0.55),
	shy = Color(0.9, 0.35, 0.45), happy = Color(0.85, 0.5, 0.1),
}
const DIM := Color(0.62, 0.62, 0.68)

var id := ""
var info := {}
var face := "normal"

var _loop: Tween
var _move: Tween
var _mark_y := 0.0

@onready var _body: Control = $Body
@onready var _sticker: TextureRect = $Body/Sticker
@onready var _tag: Label = $Body/Tag
@onready var _mark: Label = $Body/Mark


func setup(p_id: String, p_info: Dictionary, flip: bool) -> void:
	id = p_id
	info = p_info
	name = p_id
	_tag.text = info.get("name", p_id)
	_sticker.flip_h = flip
	_sticker.material = _sticker.material.duplicate()
	_show(info.get("sticker", ""))
	_mark.text = ""


func _ready() -> void:
	_mark_y = _mark.position.y
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	_body.pivot_offset = Vector2(size.x * 0.5, size.y)


## 그림을 바꿈. 못 읽으면 이름표
func _show(path: String) -> void:
	var s := Cut.load_sticker(path)
	_sticker.visible = not s.is_empty()
	_tag.visible = s.is_empty()
	if not s.is_empty():
		_sticker.texture = s.tex
		(_sticker.material as ShaderMaterial).set_shader_parameter("cut_mask", s.mask)


## 톡 붙기: 크게 → 제자리, 살짝 삐뚤게
func stick_on() -> void:
	_body.scale = Vector2.ONE * 1.25
	_body.rotation = randf_range(-0.14, 0.14)
	_body.modulate.a = 0.0
	_kill_move()
	_move = create_tween().set_parallel()
	_move.tween_property(_body, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_move.tween_property(_body, "rotation", randf_range(-0.035, 0.035), 0.2)
	_move.tween_property(_body, "modulate:a", 1.0, 0.07)


## 떼기: 귀퉁이부터 들리듯 돌며 날아감, 끝나면 사라짐
func peel_off(outward: float) -> void:
	_kill_move()
	_stop_loop()
	_move = create_tween().set_parallel()
	_move.tween_property(_body, "rotation", 0.5 * outward, 0.25).set_ease(Tween.EASE_IN)
	_move.tween_property(_body, "position", Vector2(160 * outward, -60), 0.25).set_ease(Tween.EASE_IN)
	_move.tween_property(_body, "modulate:a", 0.0, 0.25)
	_move.chain().tween_callback(queue_free)


func set_speaking(on: bool) -> void:
	modulate = Color.WHITE if on else DIM
	z_index = 1 if on else 0


func set_face(f: String) -> void:
	face = f
	var faces: Dictionary = info.get("faces", {})
	_show(faces.get(f, info.get("sticker", "")))
	_stop_loop()
	_mark.text = MARKS.get(f, "")
	_mark.add_theme_color_override("font_color", MARK_COLOR.get(f, Color(0.149, 0.204, 0.431)))
	if _mark.text.is_empty():
		return
	_mark.scale = Vector2.ONE * 0.4
	create_tween().tween_property(_mark, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match f:
		"angry":
			shake()
		"surprised":
			hop()
		"scared":
			_loop = create_tween().set_loops()
			_loop.tween_property(_sticker, "position:x", 3.0, 0.05)
			_loop.tween_property(_sticker, "position:x", -3.0, 0.05)
		"happy":
			_loop = create_tween().set_loops()
			_loop.tween_property(_mark, "position:y", _mark_y - 8, 0.3)
			_loop.tween_property(_mark, "position:y", _mark_y, 0.3)


func shake() -> void:
	_settle()
	_move = create_tween()
	for x in [14.0, -12.0, 9.0, -6.0, 0.0]:
		_move.tween_property(_body, "position:x", x, 0.04)


func hop() -> void:
	_settle()
	_move = create_tween()
	_move.tween_property(_body, "position:y", -46.0, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_move.tween_property(_body, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _kill_move() -> void:
	if _move and _move.is_valid():
		_move.kill()


## 하던 움직임을 끊고 붙은 자리로 (붙는 중이었어도 다 붙은 모양으로)
func _settle() -> void:
	_kill_move()
	_body.position = Vector2.ZERO
	_body.scale = Vector2.ONE
	_body.modulate.a = 1.0


func _stop_loop() -> void:
	if _loop and _loop.is_valid():
		_loop.kill()
	_sticker.position.x = 0.0
	_mark.position.y = _mark_y
