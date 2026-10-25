class_name Juice
extends RefCounted
## 웹게임(WAAPI) 키프레임 애니메이션을 고도에서 같은 값으로 재생하는 도구.
## frames = [{ t?, x, y, sx, sy, s, r, a, b }, …]
##   t: 0~1 오프셋 (없으면 고르게), x·y: 기준 자리에서 px, s(=sx=sy)·sx·sy: 크기, r: 도(°), a: 투명도, b: 밝기 배수
##   CSS처럼 transform(x·y·s·r)은 키프레임마다 빠진 값 = 기본값(0·1), a·b는 앞 값을 이어 씀
## ease: "linear" | "ease" | "ease-in" | "ease-out" | "ease-in-out" | [x1, y1, x2, y2] (cubic-bezier).
## 웹처럼 이징은 전체 진행에 한 번 걸고, 키프레임 사이는 직선으로 이음

const NAMED := {
	"ease": [0.25, 0.1, 0.25, 1.0], "ease-in": [0.42, 0.0, 1.0, 1.0], "ease-out": [0.0, 0.0, 0.58, 1.0],
	"ease-in-out": [0.42, 0.0, 0.58, 1.0],
}


## cubic-bezier(x1, y1, x2, y2)에서 시간 u(0~1)의 진행
static func bezier(c: Array, u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return clampf(u, 0.0, 1.0)
	var t := u
	for i in 8:  # 뉴턴법으로 x(t) = u 풀기
		var x := _b(c[0], c[2], t) - u
		var dx := _db(c[0], c[2], t)
		if absf(x) < 1e-5 or absf(dx) < 1e-6:
			break
		t = clampf(t - x / dx, 0.0, 1.0)
	return _b(c[1], c[3], t)


static func _b(p1: float, p2: float, t: float) -> float:
	var it := 1.0 - t
	return 3.0 * it * it * t * p1 + 3.0 * it * t * t * p2 + t * t * t


static func _db(p1: float, p2: float, t: float) -> float:
	var it := 1.0 - t
	return 3.0 * it * it * p1 + 6.0 * it * t * (p2 - p1) + 3.0 * t * t * (1.0 - p2)


static func ease_value(ease, u: float) -> float:
	if ease is Array:
		return bezier(ease, u)
	if ease == "linear":
		return u
	return bezier(NAMED.get(ease, NAMED["ease"]), u)


## 키프레임을 채움: transform은 빠지면 기본값, a·b는 앞 값을 이어 씀
static func normalize(frames: Array) -> Array:
	var out := []
	var a := 1.0
	var b := 1.0
	for i in frames.size():
		var f: Dictionary = frames[i]
		a = f.get("a", a)
		b = f.get("b", b)
		var s: float = f.get("s", 1.0)
		out.append({
			t = f.get("t", float(i) / maxi(1, frames.size() - 1)),
			x = f.get("x", 0.0), y = f.get("y", 0.0),
			sx = f.get("sx", s), sy = f.get("sy", s), r = f.get("r", 0.0), a = a, b = b,
		})
	return out


## node를 frames대로 움직임 (base: 기준 자리). dur·delay는 ms. 끝나면 done
static func play(node: CanvasItem, base: Vector2, frames: Array, dur: float, ease = "ease", delay := 0.0, done := Callable()) -> Tween:
	var fs := normalize(frames)
	_apply(node, base, fs[0])
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay / 1000.0)
	tw.tween_method(func(u: float): _apply(node, base, _at(fs, ease_value(ease, u))), 0.0, 1.0, maxf(dur, 1.0) / 1000.0)
	if done.is_valid():
		tw.tween_callback(done)
	return tw


static func _at(fs: Array, p: float) -> Dictionary:
	for i in range(1, fs.size()):
		if p <= fs[i].t or i == fs.size() - 1:
			var a: Dictionary = fs[i - 1]
			var b: Dictionary = fs[i]
			var span: float = b.t - a.t
			var w := 1.0 if span <= 0.0 else clampf((p - a.t) / span, 0.0, 1.0)
			var out := {}
			for k in ["x", "y", "sx", "sy", "r", "a", "b"]:
				out[k] = lerpf(a[k], b[k], w)
			return out
	return fs[-1]


static func _apply(node: CanvasItem, base: Vector2, f: Dictionary) -> void:
	node.position = base + Vector2(f.x, f.y)
	node.scale = Vector2(f.sx, f.sy)
	node.rotation_degrees = f.r
	node.modulate = Color(f.b, f.b, f.b, f.a)
