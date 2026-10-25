class_name PartySlot
extends VBoxContainer




signal pressed(slot: int)

const FILL_EASE: = [0.3, 1.3, 0.6, 1.0]
const POP_EASE: = [0.3, 1.6, 0.6, 1.0]
const BOB_PX: = 5.0

var slot: = 0
var gauge: = 0

var _full: = false
var _fill_tw: Tween
var _scale_tw: Tween
var _ready_tws: Array[Tween] = []

@onready var _ring: Control = $Ring
@onready var _bob: Control = $Ring / Bob
@onready var _glow: TextureRect = $Ring / Bob / Glow
@onready var _gauge: TextureProgressBar = $Ring / Bob / Gauge
@onready var _shine: TextureRect = $Ring / Bob / Gauge / Shine
@onready var _face: TextureRect = $Ring / Bob / Face
@onready var _ready: Label = $Ring / Bob / Face / Ready
@onready var _zz: Label = $Ring / Bob / Face / Zz
@onready var _icon: TextureRect = $Head / Icon
@onready var _attr: Label = $Head / Attr


func setup(p_slot: int, friend: Dictionary, need: int, face: Texture2D, icon: Texture2D, color: = Color.WHITE) -> void :
	slot = p_slot
	_face.texture = face
	_icon.texture = icon
	_attr.text = BattleArt.ATTR_NAME.get(friend.attr, friend.attr) + (" 회복" if friend.has("heal") else "")
	_attr.add_theme_color_override("font_color", BattleArt.ATTR_COLOR.get(friend.attr, Color.BLACK))
	_gauge.tint_progress = color
	_gauge.max_value = need
	_gauge.value = 0
	gauge = 0
	set_gauge(0, need)
	set_asleep(false)


func set_gauge(v: int, need: int) -> void :
	v = mini(v, need)
	var full: = v >= need
	if v != gauge:
		if v > gauge and not full:
			_scale([{s = 1.0}, {s = 1.1}, {s = 1.0}], 260.0, "ease-out")
		gauge = v
		if _fill_tw:
			_fill_tw.kill()
		var from: = _gauge.value
		_fill_tw = create_tween()
		_fill_tw.tween_method( func(u: float): _gauge.value = lerpf(from, v, Juice.bezier(FILL_EASE, u)), 0.0, 1.0, 0.45)
	if full and not _full:
		_scale([{s = 1.0}, {s = 1.3}, {s = 0.95}, {s = 1.0}], 420.0, POP_EASE)
		AppSound.sfx("star")
	if full != _full:
		_full = full
		_ready_fx(full)



func _ready_fx(on: bool) -> void :
	for t in _ready_tws:
		t.kill()
	_ready_tws.clear()
	_ready.visible = on
	_glow.visible = on
	_shine.visible = on
	_bob.position.y = 0.0
	if not on:
		return
	var spin: = _shine.create_tween().set_loops()
	spin.tween_property(_shine, "rotation", TAU, 1.3).from(0.0)
	var glow: = _glow.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow.tween_property(_glow, "modulate:a", 1.0, 1.0).from(0.4)
	glow.parallel().tween_property(_glow, "scale", Vector2.ONE * 1.07, 1.0).from(Vector2.ONE * 0.93)
	glow.tween_property(_glow, "modulate:a", 0.4, 1.0)
	glow.parallel().tween_property(_glow, "scale", Vector2.ONE * 0.93, 1.0)
	var bob: = _bob.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_bob, "position:y", - BOB_PX, 0.5)
	bob.tween_property(_bob, "position:y", 0.0, 0.5)
	_ready_tws = [spin, glow, bob]


func _scale(frames: Array, dur: float, ease) -> void :
	if _scale_tw:
		_scale_tw.kill()
	_scale_tw = Juice.play(_ring, _ring.position, frames, dur, ease)


func set_asleep(on: bool) -> void :
	_zz.visible = on



func face_center() -> Vector2:
	return _face.get_global_rect().get_center()


func face() -> Texture2D:
	return _face.texture


func punch() -> void :
	var tw: = _face.create_tween()
	tw.tween_property(_face, "scale", Vector2.ONE * 1.2, 0.08)
	tw.tween_property(_face, "scale", Vector2.ONE, 0.12)



func shake() -> void :
	_bob.position.x = - BOB_PX
	var tw: = _bob.create_tween()
	tw.tween_property(_bob, "position:x", BOB_PX, 0.09)
	tw.tween_property(_bob, "position:x", 0.0, 0.09)


func _gui_input(e: InputEvent) -> void :
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(slot)
