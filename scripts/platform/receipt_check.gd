class_name ReceiptCheck
extends RefCounted
## 영수증 확인 창구. 결제 창구가 purchased(p)를 보내면 보상 주기 전에 check(p)로 서버에 진짜인지 묻는다
## (docs/release/paid-spec.md §4~5). 게임 코드는 Platform.receipts()로 이것만 부른다.
## 이 클래스 자체는 "서버 없음" 구현: 늘 실패(no_server) → 보상 안 나감, finish 안 함 → 다음 실행 때 다시.
## 진짜는 ServerReceiptCheck (server/ 영수증 서버), 테스트용은 FakeReceiptCheck.
##
## 게임을 켤 때마다 check_revoked(받은 주문 번호들) → revoked_found(환불된 것들) → 메타가 회수.
## 서버에 못 닿으면 revoked_found가 안 온다 (다음에 다시 물으면 됨).

## r = { ok, reason, expires_ms, test }
##   reason: invalid(가짜) refunded pending expired used_elsewhere unsupported error no_server
##   expires_ms: 구독이면 만료 시각(ms), 아니면 0. test: 라이선스 테스터 결제 (돈 안 나감)
signal checked(p: Dictionary, r: Dictionary)
signal revoked_found(order_ids: Array)

var deferred := true  # false면 신호를 바로 보냄 (테스트)


func check(p: Dictionary) -> void:
	_check(p)


func check_revoked(order_ids: Array) -> void:
	_check_revoked(order_ids)


# ---------- 상속해서 채우는 곳 ----------

func _check(p: Dictionary) -> void:
	_done(p, {ok = false, reason = "no_server", expires_ms = 0, test = false})


func _check_revoked(_order_ids: Array) -> void:
	_emit(revoked_found, [[]])


func _done(p: Dictionary, r: Dictionary) -> void:
	_emit(checked, [p, r])


## 신호를 다음 프레임에 보냄 (deferred = false면 바로)
func _emit(sig: Signal, args: Array) -> void:
	if deferred:
		(func(): sig.emit.callv(args)).call_deferred()
	else:
		sig.emit.callv(args)
