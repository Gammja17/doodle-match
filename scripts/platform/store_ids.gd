class_name StoreIds
extends RefCounted
## 스토어 상품 ID·광고 단위 ID를 두는 곳은 여기 하나. 지금은 전부 비어 있음.
## 플레이 콘솔·앱스토어 커넥트·AdMob에서 만든 뒤 빈 "" 를 채운다 (docs/release/billing-ads.md).
## 게임 코드는 왼쪽 키(내부 이름)만 쓴다. 상품을 사면 무엇을 주는지는 여기 말고 메타 쪽이 정한다.
##
## kind
##   consumable      여러 번 사는 것 (별가루 묶음, 시즌북)
##   once            계정당 한 번이지만 스토어에선 소모형 (처음 상자, 성장 지원). 한 번만 파는 건 게임이 막음
##   non_consumable  한 번 사면 영원히 (광고 없이 받기, 유료 코스튬). 기기를 바꾸면 restore()로 다시 받음
##   subscription    자동 갱신 구독 (월간 스티커북). 만료 시각은 영수증 서버가 알려 줌
## price_krw: bm.md 가격. 가짜 결제가 가격표로 보여 주는 값일 뿐, 실제 가격은 스토어 콘솔에서 정함

const PRODUCTS := {
	dust_60 = {kind = "consumable", price_krw = 1200, android = "", ios = ""},
	dust_320 = {kind = "consumable", price_krw = 5900, android = "", ios = ""},
	dust_680 = {kind = "consumable", price_krw = 12000, android = "", ios = ""},
	dust_1700 = {kind = "consumable", price_krw = 29000, android = "", ios = ""},
	dust_3600 = {kind = "consumable", price_krw = 59000, android = "", ios = ""},
	dust_6200 = {kind = "consumable", price_krw = 99000, android = "", ios = ""},
	monthly_book = {kind = "subscription", price_krw = 5900, android = "", ios = ""},
	season_book = {kind = "consumable", price_krw = 11000, android = "", ios = ""},
	growth_pack = {kind = "once", price_krw = 12000, android = "", ios = ""},
	starter_box = {kind = "once", price_krw = 1200, android = "", ios = ""},
	no_ads = {kind = "non_consumable", price_krw = 8800, android = "", ios = ""},
	# 유료 코스튬은 하나에 상품 하나 (costume_<친구 id>_<옷 id>). 첫 코스튬이 정해지면 여기 줄을 더한다
}

## 보상형 광고 자리 (bm.md §4). 전면·배너 광고는 없음
const AD_SLOTS := {
	"heart": {android = "", ios = ""},        # 하트 +1
	"continue": {android = "", ios = ""},     # 실패한 판 이어하기 (continue는 예약어라 따옴표)
	"coins_x2": {android = "", ios = ""},     # 판 코인 2배
	"free_gacha": {android = "", ios = ""},   # 일반 뽑기 1회
	"vault_again": {android = "", ios = ""},  # 보물창고 한 번 더
}

## AdMob 앱 ID (광고 단위 ID와 다름). 안드로이드는 익스포트 설정에도 같은 값을 넣는다
const ADMOB_APP_ID := {android = "", ios = ""}

## 영수증 확인 서버 주소 (docs/release/paid-spec.md §5). 비어 있으면 릴리스 빌드에선 확인이 늘 실패 = 보상 안 나감
const VERIFY_URL := ""


## 이 기기 스토어의 상품 ID. 비어 있으면 아직 안 채운 것
static func store_id(key: String, os := OS.get_name()) -> String:
	return String(PRODUCTS[key].get(_store(os), ""))


static func ad_unit(slot: String, os := OS.get_name()) -> String:
	return String(AD_SLOTS[slot].get(_store(os), ""))


## 아직 빈 ID 목록 (출시 전 확인용). "android:dust_60" 모양
static func missing(os_list := ["android", "ios"]) -> Array:
	var out := []
	for s in os_list:
		for k in PRODUCTS:
			if String(PRODUCTS[k][s]) == "":
				out.append("%s:%s" % [s, k])
		for k in AD_SLOTS:
			if String(AD_SLOTS[k][s]) == "":
				out.append("%s:ad.%s" % [s, k])
		if String(ADMOB_APP_ID[s]) == "":
			out.append("%s:admob_app_id" % s)
	return out


static func _store(os: String) -> String:
	return "ios" if os == "iOS" or os == "ios" else "android"
