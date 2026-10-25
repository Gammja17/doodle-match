class_name AppLayer
extends CanvasLayer
## 모든 화면 위에 하나: 화면 넘길 때 쓸고 지나가는 종이(+로딩 글자), 위에서 내려오는 쪽지(toast), 묻는 창(ask).
## 값은 웹게임 그대로 (docs/ui-port.md): 와이프 = 화면보다 큰 종이 한 장이 −4° 기울어 왼쪽→오른쪽,
## 들어옴 240ms cubic-bezier(.3,.8,.4,1) · 60ms 멈춤 · 나감 260ms cubic-bezier(.6,0,.7,.2). 가운데 친구 스티커가 통통.

const WIPE_IN := 240.0
const WIPE_OUT := 260.0
const IN_EASE := [0.3, 0.8, 0.4, 1.0]
const OUT_EASE := [0.6, 0.0, 0.7, 0.2]
const TOAST_TIME := 2600.0

var _toast_tw: Tween
var _hop_tw: Tween
var _on_ok: Callable


func _ready() -> void:
	%Cover.hide()
	%Loading.hide()
	%Toast.hide()
	%Dialog.hide()
	%Cancel.pressed.connect(close_dialog)
	%Ok.pressed.connect(func():
		var f := _on_ok
		close_dialog()
		f.call())


## 종이 자리: 화면 폭의 130%·높이 120%, 왼쪽 위 −15%·−10% (웹 .wipe inset) + 가로로 k(−1 왼쪽 밖, 0 덮음, 1 오른쪽 밖)
func _sheet_x(k: float) -> float:
	var w: float = %Cover.size.x
	return -0.15 * w + k * 1.05 * 1.3 * w


func cover() -> void:
	var c: Control = %Cover
	var s: Control = %Sheet
	c.show()
	s.size = c.size * Vector2(1.3, 1.2)
	s.pivot_offset = s.size / 2
	s.rotation_degrees = -4.0
	s.position = Vector2(_sheet_x(-1.0), -0.1 * c.size.y)
	_hopper()
	var tw := create_tween()
	tw.tween_method(func(u: float): s.position.x = lerpf(_sheet_x(-1.0), _sheet_x(0.0), Juice.bezier(IN_EASE, u)), 0.0, 1.0, WIPE_IN / 1000.0)
	await tw.finished


func uncover() -> void:
	var s: Control = %Sheet
	await get_tree().create_timer(0.06).timeout
	var tw := create_tween()
	tw.tween_method(func(u: float): s.position.x = lerpf(_sheet_x(0.0), _sheet_x(1.0), Juice.bezier(OUT_EASE, u)), 0.0, 1.0, WIPE_OUT / 1000.0)
	await tw.finished
	%Cover.hide()
	if _hop_tw:
		_hop_tw.kill()


## 가운데 친구: 파티에서 아무나 (없으면 비움), 통통 .5s
func _hopper() -> void:
	var h: TextureRect = %Hopper
	var party := AppState.party()
	h.texture = FriendLook.shared().sticker(party.pick_random()) if not party.is_empty() else null
	if _hop_tw:
		_hop_tw.kill()
	h.position = Vector2(h.get_parent().size.x / 2 - 90, h.get_parent().size.y / 2 - 110)
	_hop_tw = AppFx.hop(h, 500.0)


func show_loading(on: bool) -> void:
	%Loading.visible = on


## 쪽지: 위(96px)에서 −30px·투명 → 12% 제자리 → 85%까지 머묾 → −15px·투명, 2600ms ease-out (웹 미션 쪽지)
func toast(text: String) -> void:
	%ToastText.text = text
	var t: Control = %Toast
	t.show()
	if _toast_tw:
		_toast_tw.kill()
	t.position.y = 96.0
	_toast_tw = AppFx.play(t, [{y = -30.0, a = 0.0}, {t = 0.12, y = 0.0, a = 1.0}, {t = 0.85, y = 0.0, a = 1.0}, {y = -15.0, a = 0.0}], TOAST_TIME, "ease-out")
	_toast_tw.tween_callback(t.hide)


func ask(text: String, ok_label: String, on_ok: Callable) -> void:
	%Ask.text = text
	%Ok.text = ok_label
	_on_ok = on_ok
	%Dialog.show()
	var p: Control = %Panel
	p.modulate.a = 0.0
	await get_tree().process_frame  # 가운데 정렬이 끝난 크기로
	AppFx.pop_small(p)


## 묻는 창이 열려 있었으면 닫고 true (웹처럼 닫힘은 바로)
func close_dialog() -> bool:
	if not %Dialog.visible:
		return false
	%Dialog.hide()
	return true


func is_asking() -> bool:
	return %Dialog.visible
