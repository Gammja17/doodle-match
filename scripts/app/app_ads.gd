class_name AppAds
extends RefCounted
## 보상형 광고 하나 보고 결과 기다리기. 광고 창구는 출시 준비 세션의 Platform.ads(), 하루 한도·보상은 메타(ad_left, ad_reward).
## 끝까지 보면 메타가 보상을 줌: heart 하트 +1, free_gacha 코인 캡슐 티켓 +1, coins_x2 그 판 코인만큼 더, continue는 횟수만 (이동은 판 화면이).
## "광고 없이 받기"를 샀으면(data.no_ads) 광고 없이 바로 받음 (Ads.skip)


class _Waiter:
	extends RefCounted
	signal done(ok: bool)

	func on_closed(_slot: String, got: bool) -> void:
		done.emit(got)

	func on_failed(_slot: String, _reason: String) -> void:
		done.emit(false)


static func left(slot: String) -> int:
	return AppState.meta().ad_left(slot)


static func can(slot: String) -> bool:
	var ads := Platform.ads()
	ads.skip = AppState.meta().data.get("no_ads", false)
	return left(slot) > 0 and ads.can_show(slot)


## 광고를 끝까지 봤고 메타가 보상을 줬으면 true. amount = coins_x2일 때 더 줄 코인
static func watch(slot: String, amount := 0) -> bool:
	if not can(slot):
		return false
	var ads := Platform.ads()
	var w := _Waiter.new()
	ads.closed.connect(w.on_closed)
	ads.failed.connect(w.on_failed)
	ads.show(slot)
	var ok: bool = await w.done
	ads.closed.disconnect(w.on_closed)
	ads.failed.disconnect(w.on_failed)
	return ok and AppState.meta().ad_reward(slot, amount)
