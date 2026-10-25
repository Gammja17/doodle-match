class_name ArtViewer
extends Control




signal closed

const SWIPE_PX: = 90.0
const TAP_PX: = 16.0
const DOUBLE_MS: = 300
const ZOOM: = 2.0
const ZOOM_MAX: = 3.0

var ids: Array = []
var index: = 0

var _down: = false
var _down_at: = Vector2.ZERO
var _last_tap_ms: = -1000
var _close_timer: SceneTreeTimer
var _art_base: = Vector2.ZERO


func _ready() -> void :
	%Art.resized.connect( func(): %Art.pivot_offset = %Art.size / 2)



func open(p_ids: Array, p_index: int) -> void :
	ids = p_ids
	index = clampi(p_index, 0, maxi(0, ids.size() - 1))
	_show(ids[index])
	show()
	_reset_zoom()
	AppSound.sfx("popup")
	AppFx.play( %Frame, [{s = 0.85, a = 0.0}, {s = 1.0, a = 1.0}], 240, "ease-out")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.16)


func close() -> void :
	if not visible:
		return
	hide()
	closed.emit()


func current_id() -> String:
	return ids[index] if index < ids.size() else ""


func _show(id: String) -> void :
	var look: = FriendLook.shared()
	var card: = look.card(id)
	%Art.texture = card if card else look.sticker(id)
	%Name.text = look.name_of(id)
	var attr: = look.attr(id)
	var tier: = look.tier(id)
	%AttrIcon.texture = FriendLook.attr_icon(attr)
	var bits: = [FriendLook.attr_name(attr)]
	if tier > 0:
		bits.append("%d성 %s" % [tier, FriendLook.TIER_NAME[tier]])
	if look.job(id) != "":
		bits.append(look.job(id))
	%Attr.text = " · ".join(bits)



func step(dir: int) -> void :
	if ids.size() < 2:
		AppFx.no( %Frame)
		return
	index = posmod(index + dir, ids.size())
	_show(ids[index])
	_reset_zoom()
	AppSound.sfx("page")
	var w: float = %Frame.size.x * 0.35
	AppFx.play( %Frame, [{x = w * dir, a = 0.0}, {x = 0.0, a = 1.0}], 220, "ease-out")


func is_zoomed() -> bool:
	return %Art.scale.x > 1.01


func _reset_zoom() -> void :
	var a: TextureRect = %Art
	a.scale = Vector2.ONE
	a.position = Vector2.ZERO
	_art_base = Vector2.ZERO



func _zoom_to(k: float, at: Vector2) -> void :
	var a: TextureRect = %Art
	var local: Vector2 = (at - %Frame.position - a.position - a.pivot_offset) / a.scale.x
	a.scale = Vector2(k, k)
	a.position = at - %Frame.position - a.pivot_offset - local * k
	if k <= 1.01:
		_reset_zoom()


func _gui_input(e: InputEvent) -> void :
	if e is InputEventMagnifyGesture:
		_zoom_to(clampf( %Art.scale.x * e.factor, 1.0, ZOOM_MAX), e.position)
		accept_event()
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if e.pressed:
			_down = true
			_down_at = e.position
			_art_base = %Art.position
		elif _down:
			_down = false
			_release(e.position)
	elif _down and e is InputEventMouseMotion and is_zoomed():
		%Art.position = _art_base + (e.position - _down_at)
		accept_event()


func _release(at: Vector2) -> void :
	var d: = at - _down_at
	if not is_zoomed() and absf(d.x) >= SWIPE_PX and absf(d.x) > absf(d.y):
		step(-1 if d.x > 0 else 1)
		return
	if d.length() > TAP_PX:
		return
	var now: = Time.get_ticks_msec()
	if now - _last_tap_ms <= DOUBLE_MS:
		_last_tap_ms = -1000
		_close_timer = null
		_zoom_to(1.0 if is_zoomed() else ZOOM, at)
		return
	_last_tap_ms = now
	var t: = get_tree().create_timer(DOUBLE_MS / 1000.0)
	_close_timer = t
	t.timeout.connect( func():
		if _close_timer == t:
			close())
