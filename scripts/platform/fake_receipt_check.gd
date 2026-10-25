class_name FakeReceiptCheck
extends ReceiptCheck
## 가짜 영수증 확인: 서버 없이 바로 확인된 셈. 에디터·디버그 빌드에서만 쓴다. 구독은 지금부터 30일 뒤에 끝남.

const MONTH_MS := 30 * 86400000

## 다음 check() 결과 하나: ok | invalid | refunded | pending | error. 한 번 쓰면 ok로
var next := "ok"
## 환불된 셈 칠 주문 번호 (check_revoked 흉내)
var refunded := []
var clock := func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)  # 테스트에서 바꿔 끼움


func _check(p: Dictionary) -> void:
	var r := next
	next = "ok"
	if r != "ok":
		_done(p, {ok = false, reason = r, expires_ms = 0, test = false})
		return
	var until: int = clock.call() + MONTH_MS if p.get("kind") == "subscription" else 0
	_done(p, {ok = true, reason = "", expires_ms = until, test = false})


func _check_revoked(order_ids: Array) -> void:
	_emit(revoked_found, [order_ids.filter(func(o): return o in refunded)])
