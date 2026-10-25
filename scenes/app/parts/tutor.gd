class_name Tutor
extends Control






signal tapped

const TIP: = Vector2(32, 6)
const PAD: = 8.0
const FACE: = "grenn"
const BUBBLE_MAX: = 520.0

var _tw: Tween
var _ring_tw: Tween


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Catcher.gui_input.connect(_on_tap_input)
	for c in %Shade.get_children():
		if c is ColorRect:
			c.gui_input.connect(_on_tap_input)
	clear()


func _on_tap_input(e: InputEvent) -> void :
	if e is InputEventMouseButton and e.pressed:
		tapped.emit()



func spot(rect: Rect2, text: String, face_id: = FACE) -> void :
	var r: = Rect2(rect.position - global_position, rect.size).grow(PAD)
	var w: = size.x
	var h: = size.y
	var parts: = {
		"Top": Rect2(0, 0, w, r.position.y), 
		"Bottom": Rect2(0, r.end.y, w, h - r.end.y), 
		"Left": Rect2(0, r.position.y, r.position.x, r.size.y), 
		"Right": Rect2(r.end.x, r.position.y, w - r.end.x, r.size.y), 
	}
	var was_shown: bool = %Shade.visible
	for k in parts:
		var c: Control = %Shade.get_node(k)
		c.position = parts[k].position
		c.size = parts[k].size.max(Vector2.ZERO)
	var ring: Control = %Ring
	ring.position = r.position
	ring.size = r.size
	%Shade.show()
	if not was_shown:
		%Shade.modulate.a = 0.0
		create_tween().tween_property( %Shade, "modulate:a", 1.0, 0.22)
	if _ring_tw:
		_ring_tw.kill()
	_ring_tw = AppFx.pulse(ring)
	_say(text, face_id, r)



func _say(text: String, face_id: String, r: Rect2) -> void :
	var b: Control = %Bubble
	%Say.text = text
	%Face.texture = FriendLook.shared().face(face_id)
	var say: Label = %Say
	say.autowrap_mode = TextServer.AUTOWRAP_OFF
	say.custom_minimum_size.x = 0.0
	b.show()
	b.size = Vector2.ZERO
	var max_w: = minf(BUBBLE_MAX, size.x - 36.0)
	if b.size.x > max_w:
		say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		say.custom_minimum_size.x = max_w - (b.size.x - say.size.x)
		b.size = Vector2.ZERO
	var bh: = b.size.y
	var y: = r.end.y + 18.0 if r.end.y + 18.0 + bh < size.y - 18.0 else r.position.y - 18.0 - bh
	b.position = Vector2(clampf(r.get_center().x - b.size.x / 2, 18.0, size.x - 18.0 - b.size.x), clampf(y, 18.0, size.y - 18.0 - bh))
	AppFx.play(b, [{s = 0.6, a = 0.0}, {s = 1.0, a = 1.0}], 260, AppFx.OVERSHOOT, 120)


func clear() -> void :
	%Shade.hide()
	%Bubble.hide()
	%Catcher.hide()
	if _ring_tw:
		_ring_tw.kill()
	_stop_finger()


func _stop_finger() -> void :
	if _tw:
		_tw.kill()
	%Finger.hide()



func point_move(from: Vector2, to: Vector2) -> void :
	_stop_finger()
	var f: Control = %Finger
	f.show()
	_tw = create_tween().set_loops()
	_tw.tween_callback( func():
		f.global_position = from - TIP
		f.modulate.a = 1.0)
	_tw.tween_interval(0.25)
	_tw.tween_property(f, "global_position", to - TIP, 0.5).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(f, "modulate:a", 0.0, 0.25)
	_tw.tween_interval(0.3)



func point_at(target: Control) -> void :
	_stop_finger()
	var f: Control = %Finger
	f.show()
	f.modulate.a = 1.0
	var at: = target.get_global_rect().get_center() + Vector2(0, target.size.y * 0.3) - TIP
	f.global_position = at
	_tw = create_tween().set_loops()
	_tw.tween_property(f, "global_position", at + Vector2(0, 18), 0.35).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(f, "global_position", at, 0.35).set_trans(Tween.TRANS_SINE)



func wait_tap() -> void :
	%Catcher.show()
	await tapped
	%Catcher.hide()
