class_name FakeBilling
extends Billing
## 가짜 결제: 돈 없이 바로 산 셈. 에디터·디버그 빌드에서만 쓴다 (Platform.billing()이 릴리스에선 안 고름).
## next를 바꿔 실패·취소·보류를 흉내 낸다. 끝나지 않은 결제·가진 영구 상품은 이 객체가 살아 있는 동안만 기억함.

## 다음 buy() 결과 하나: ok | cancelled | pending | error. 한 번 쓰면 ok로 돌아감
var next := "ok"
var _n := 0
var _open := {}   # order_id -> 아직 finish 안 한 결제
var _owned := {}  # 가진 영구 상품·구독 키 -> 결제 (가짜 구독은 끝나지 않음)


func _start() -> void:
	_set_ready(true)
	for p in _open.values():
		_emit(purchased, [p])


func _products() -> Dictionary:
	if not _ok:
		return {}
	var out := {}
	for k in StoreIds.PRODUCTS:
		out[k] = {price_text = "₩%s (가짜)" % _comma(StoreIds.PRODUCTS[k].price_krw)}
	return out


func _buy(key: String) -> void:
	var r := next
	next = "ok"
	if _owned.has(key):
		r = "owned"
	if r != "ok":
		_fail(key, r)
		return
	_n += 1
	var p := {key = key, kind = StoreIds.PRODUCTS[key].kind, order_id = "FAKE.%04d" % _n, token = "fake-token-%d" % _n}
	_open[p.order_id] = p
	_emit(purchased, [p])


func _finish(p: Dictionary) -> void:
	_open.erase(p.get("order_id", ""))
	if p.get("kind") in ["non_consumable", "subscription"]:
		_owned[p.key] = p


func _restore() -> void:
	for p in _owned.values():
		_emit(purchased, [p])


static func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
