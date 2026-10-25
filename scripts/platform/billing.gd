class_name Billing
extends RefCounted
## 앱 안 결제 창구. 게임 코드는 Platform.billing()으로 이것만 부르고 플러그인을 직접 안 부른다.
## 이 클래스 자체는 "결제 없음" 구현이다 (웹·PC, 플러그인이 아직 없는 릴리스 빌드): 늘 준비 안 됨, 사면 unavailable.
## 진짜 구현(구글 플레이·앱스토어)은 이걸 상속해서 _start/_buy/_finish/_restore만 채운다. 테스트용은 FakeBilling.
##
## 흐름
##   start() → ready_changed(true) → products()로 가격 글자 표시 → buy(key)
##   → purchased(p) → Platform.receipts().check(p) → checked(p, r)이 ok면 게임이 보상을 주고 저장한 다음 finish(p)
##   (ok가 아니면 보상도 finish도 안 함)
##   finish()를 안 부르면 다음 start() 때 같은 결제가 purchased로 다시 온다
##   (보상 주기 전에 앱이 꺼져도 결제를 잃지 않게. 구글은 3일 안에 finish 안 하면 자동 환불).
##   같은 order_id가 두 번 오면 게임은 보상을 두 번 주지 않아야 한다.
## 신호는 플러그인처럼 늘 나중에(다음 프레임) 온다고 생각하고 짠다.

signal ready_changed(ok: bool)
## p = { key, kind, order_id, token }
signal purchased(p: Dictionary)
## reason: cancelled(사용자가 닫음) pending(보호자 승인 대기 등, 나중에 purchased로 옴)
##         owned(이미 가진 영구 상품) unavailable(결제 못 함) error
signal failed(key: String, reason: String)

var deferred := true  # false면 신호를 바로 보냄 (테스트)
var _ok := false


func start() -> void:
	_start()


func is_ready() -> bool:
	return _ok


## 키 -> { price_text } . 준비 전이나 결제가 없으면 빈 Dictionary
func products() -> Dictionary:
	return _products()


func buy(key: String) -> void:
	if not StoreIds.PRODUCTS.has(key):
		_fail(key, "error")
	elif not _ok:
		_fail(key, "unavailable")
	else:
		_buy(key)


## 보상을 다 주고 저장한 다음에 부른다. 소모형은 소모, 영구 상품은 확인(acknowledge)
func finish(p: Dictionary) -> void:
	_finish(p)


## 영구 상품(no_ads, 코스튬)과 살아 있는 구독을 다시 받음. 가진 것마다 purchased가 다시 온다 (앱스토어 심사에 "구매 복원" 단추 필수)
func restore() -> void:
	_restore()


## 스토어 구독 관리 화면 (해지·결제 수단). 플러그인 없이 OS.shell_open으로 열림
static func subscriptions_url(store_id := "", package := "", os := OS.get_name()) -> String:
	if os == "iOS":
		return "https://apps.apple.com/account/subscriptions"
	var u := "https://play.google.com/store/account/subscriptions"
	return u + ("?sku=%s&package=%s" % [store_id, package] if store_id != "" else "")


# ---------- 상속해서 채우는 곳 ----------

func _start() -> void:
	_set_ready(false)


func _products() -> Dictionary:
	return {}


func _buy(key: String) -> void:
	_fail(key, "unavailable")


func _finish(_p: Dictionary) -> void:
	pass


func _restore() -> void:
	pass


# ---------- 상속한 쪽이 쓰는 도우미 ----------

func _set_ready(ok: bool) -> void:
	_ok = ok
	_emit(ready_changed, [ok])


func _fail(key: String, reason: String) -> void:
	_emit(failed, [key, reason])


## 신호를 다음 프레임에 보냄 (deferred = false면 바로)
func _emit(sig: Signal, args: Array) -> void:
	if deferred:
		(func(): sig.emit.callv(args)).call_deferred()
	else:
		sig.emit.callv(args)
