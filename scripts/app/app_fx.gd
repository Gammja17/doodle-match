class_name AppFx
extends RefCounted
## 앱 화면 연출: 웹게임(chiikawa-match) css/js 값을 그대로 옮김 (docs/ui-port.md 표). 보드 세션 Juice(키프레임·베지어)를 그대로 씀.
## Control은 가운데를 축으로 (pivot = size/2) 크기·회전, 자리·기울기는 지금 값 기준.
## 끝은 늘 제자리(크기 1·원래 기울기·불투명)로 돌려놓음. 색(modulate rgb)은 건드리지 않음.

const OVERSHOOT := [0.3, 1.5, 0.6, 1.0]  # 작은 창 등장
const BOUNCE := [0.3, 1.6, 0.6, 1.0]  # 별·숫자·되돌림 튕김
const SLAM := [0.6, 0.0, 0.9, 0.6]  # 도장 쾅 (점점 빨라짐)


## 키프레임 재생 (dur·delay ms). frames는 Juice 형식 { t, x, y, s, sx, sy, r, a }
static func play(node: Control, frames: Array, dur: float, ease = "ease", delay := 0.0) -> Tween:
	node.pivot_offset = node.size / 2
	var base := [node.position, node.rotation_degrees]
	var fs := Juice.normalize(frames)
	_apply(node, base, fs[0])
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay / 1000.0)
	tw.tween_method(func(u: float): _apply(node, base, Juice._at(fs, Juice.ease_value(ease, u))), 0.0, 1.0, maxf(dur, 1.0) / 1000.0)
	return tw


## 반복 (hop·bob·pulse). delay는 첫 시작만 늦춤
static func loop(node: Control, frames: Array, dur: float, delay := 0.0, ease = "ease-in-out") -> Tween:
	node.pivot_offset = node.size / 2
	var base := [node.position, node.rotation_degrees]
	var fs := Juice.normalize(frames)
	var tw := node.create_tween().set_loops()
	tw.tween_method(func(u: float): _apply(node, base, Juice._at(fs, Juice.ease_value(ease, u))), 0.0, 1.0, dur / 1000.0)
	if delay > 0.0:
		tw.pause()
		node.get_tree().create_timer(delay / 1000.0).timeout.connect(func(): if is_instance_valid(node): tw.play())
	return tw


## Juice._apply와 같되 원래 기울기에 더하고, 색은 두고 투명도만 (카드 기울기·색종이 색이 안 날아가게)
static func _apply(node: Control, base: Array, f: Dictionary) -> void:
	node.position = base[0] + Vector2(f.x, f.y)
	node.scale = Vector2(f.sx, f.sy)
	node.rotation_degrees = base[1] + f.r
	node.modulate.a = f.a


## 큰 팝업(결과): scale .5 → 60% 1.06 → 1, 380ms ease-out
static func pop_modal(node: Control) -> Tween:
	return play(node, [{s = 0.5, a = 0.0}, {t = 0.6, s = 1.06, a = 1.0}, {s = 1.0}], 380, "ease-out")


## 작은 창(설정·일시정지·묻는 창): scale .6 → 1, 220ms overshoot
static func pop_small(node: Control) -> Tween:
	return play(node, [{s = 0.6, a = 0.0}, {s = 1.0, a = 1.0}], 220, OVERSHOOT)


## 아래에서 올라오는 시트(친구 상세): y 60% → 70% −3% → 0, 320ms ease-out
static func sheet_up(node: Control) -> Tween:
	var h := node.size.y
	return play(node, [{y = h * 0.6, a = 0.0}, {t = 0.7, y = -h * 0.03, a = 1.0}, {y = 0.0}], 320, "ease-out")


## 도장 쾅 (판 깸): 2.6배 −24° → 70% .88 −10° → 1 −12°, 320ms
static func slam(node: Control, delay := 0.0) -> Tween:
	return play(node, [{s = 2.6, r = -24.0, a = 0.0}, {t = 0.7, s = 0.88, r = -10.0, a = 1.0}, {s = 1.0, r = -12.0}], 320, SLAM, delay)


## 별 하나 박힘: 2.2배 −30° 투명 → 1, 350ms 튕김
static func star_pop(node: Control, delay := 0.0) -> Tween:
	return play(node, [{s = 2.2, r = -30.0, a = 0.0}, {s = 1.0, r = 0.0, a = 1.0}], 350, BOUNCE, delay)


## 톡 커졌다 돌아옴 (코인 칩 1.25 300ms, 카드 1.06 200ms)
static func pop(node: Control, to := 1.25, dur := 300.0) -> Tween:
	return play(node, [{s = 1.0}, {s = to}, {s = 1.0}], dur, "linear")


## 못 누름 흔들기: x −5 → 5 → 0, 200ms
static func no(node: Control, px := 5.0, dur := 200.0) -> Tween:
	return play(node, [{x = 0.0}, {x = -px}, {x = px}, {x = 0.0}], dur, "linear")


## 통통 (hop 1.3s): 40% y −10 · .97×1.03, 55% 1.04×.96
static func hop(node: Control, dur := 1300.0, delay := 0.0) -> Tween:
	return loop(node, [{y = 0.0}, {t = 0.4, y = -10.0, sx = 0.97, sy = 1.03}, {t = 0.55, y = 0.0, sx = 1.04, sy = 0.96}, {y = 0.0}], dur, delay)


## 둥실 (bob 1.6s): y 0 → −4 → 0
static func bob(node: Control, px := 4.0, dur := 1600.0) -> Tween:
	return loop(node, [{y = 0.0}, {y = -px}, {y = 0.0}], dur)


## 두근 (pulse 1.2s): 1 → 1.06 → 1
static func pulse(node: Control, dur := 1200.0) -> Tween:
	return loop(node, [{s = 1.0}, {s = 1.06}, {s = 1.0}], dur)
