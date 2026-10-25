class_name Platform
extends RefCounted
## 결제·영수증 확인·광고를 고르는 곳. 게임 코드는 Platform.billing() / receipts() / ads()만 부른다.
##   에디터·디버그 빌드: 가짜 (돈·광고 없이 바로 성공)
##   릴리스 빌드: 플러그인 구현이 있으면 그것, 없으면 "없음" (사면 unavailable, 광고 단추 꺼짐)
## 릴리스에서 가짜를 고르면 별가루가 공짜로 나오므로 절대 안 고른다.
## 플러그인을 넣으면 _real_billing / _real_ads에서 Engine.has_singleton(...)을 보고 그 구현을 돌려준다
## (docs/release/billing-ads.md).

const INSTALL_ID_PATH := "user://install_id"

static var _install_id := ""
static var _billing: Billing
static var _receipts: ReceiptCheck
static var _ads: Ads


static func billing() -> Billing:
	if _billing == null:
		_billing = _real_billing()
		if _billing == null:
			_billing = FakeBilling.new() if use_fake() else Billing.new()
	return _billing


## 서버 주소(StoreIds.VERIFY_URL)가 있으면 진짜, 없으면 디버그는 가짜·릴리스는 "서버 없음"(늘 실패)
static func receipts() -> ReceiptCheck:
	if _receipts == null:
		_receipts = _real_receipts()
		if _receipts == null:
			_receipts = FakeReceiptCheck.new() if use_fake() else ReceiptCheck.new()
	return _receipts


static func ads() -> Ads:
	if _ads == null:
		_ads = _real_ads()
		if _ads == null:
			_ads = FakeAds.new() if use_fake() else Ads.new()
	return _ads


static func use_fake() -> bool:
	return OS.is_debug_build()


## 테스트에서 다른 구현을 끼울 때
static func reset(billing_impl: Billing = null, ads_impl: Ads = null, receipts_impl: ReceiptCheck = null) -> void:
	_billing = billing_impl
	_ads = ads_impl
	_receipts = receipts_impl


## 구글 플레이 결제(GodotGooglePlayBilling)·앱스토어 결제 구현 자리. 아직 없음
static func _real_billing() -> Billing:
	return null


## 영수증 서버가 있고(VERIFY_URL) 안드로이드면 진짜 확인. 서버가 아직 iOS를 못 보고, 웹·PC엔 결제가 없음
static func _real_receipts(verify_url := StoreIds.VERIFY_URL, os := OS.get_name()) -> ReceiptCheck:
	if verify_url == "" or os != "Android":
		return null
	return ServerReceiptCheck.new(verify_url, install_id())


## 이 설치의 무작위 UUID (영수증 서버에 같이 보냄. 기기·광고 ID 아님). 처음 부를 때 만들어 파일에 둠
static func install_id(path := INSTALL_ID_PATH) -> String:
	if _install_id != "" and path == INSTALL_ID_PATH:
		return _install_id
	var id := FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""
	if id.length() < 16:
		id = _uuid4()
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(id)
	if path == INSTALL_ID_PATH:
		_install_id = id
	return id


static func _uuid4() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


## AdMob 구현 자리. 아직 없음
static func _real_ads() -> Ads:
	return null
