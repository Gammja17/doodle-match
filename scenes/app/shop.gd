class_name Shop
extends Control
## 가게 (문구점). 탭 셋:
##   캡슐: 코인 캡슐 1번(티켓이 있으면 티켓)/10번 (Meta.pull), 광고 보고 1번 무료(하루 한도는 메타), 조각 주머니
##   반짝 뽑기: 별가루 1번/10번(처음 10번 반값, 10번째 칸 ★2 이상) (Meta.pull_sparkle), 픽업 친구, 별 도장·천장 교환 (Meta.pity_exchange)
##   상점: 결제 상품 (products.json + Platform.billing() 가격), 사기 전 확인 창(가격·청약철회 안내), 구매 복원
## 확률 보기: 캡슐 = 뽑을 수 있는 친구 같은 확률, 반짝 = Meta.sparkle_rates() (실제 뽑기와 같은 표)
## 화면 구성은 웹게임 #gacha: 위 줄 [뒤로 | 문구점 | 재화], 가운데 알약 탭, 큰 캡슐, [1번(보통) | 10번(강조)] 단추

const FRIEND_ICON := preload("res://scenes/app/parts/friend_icon.tscn")
const BG := {"capsule": "res://ui/screens/art/bg_shop.jpg", "sparkle": "res://ui/screens/art/bg_gacha.jpg", "store": "res://ui/screens/art/bg_shop.jpg"}
const PRODUCT_NAME := {
	"dust_60": "별가루 60", "dust_320": "별가루 320", "dust_680": "별가루 680", "dust_1700": "별가루 1,700",
	"dust_3600": "별가루 3,600", "dust_6200": "별가루 6,200", "monthly_book": "월간 스티커북 (30일)",
	"season_book": "시즌 스티커북", "growth_pack": "성장 지원", "starter_box": "처음 상자", "no_ads": "광고 없이 받기",
}
const GOT_NAME := {"season_pass": "시즌 스티커북", "growth_pack": "성장 지원", "no_ads": "광고 없이 받기"}
## 결제 전 확인 문구 (청약철회 안내 — 정확한 문구는 출시 준비 세션 docs/release/terms.md 기준으로 바꿀 것)
const REFUND_NOTE := "결제하면 바로 받아. 받은 별가루를 쓰지 않았으면 7일 안에 청약철회할 수 있어 (쓴 뒤엔 안 돼)."

var tab := "capsule"


func _ready() -> void:
	SafeArea.apply(%Screen)
	AppSound.bgm("shop")
	for t in ["Capsule", "Sparkle", "Store"]:
		get_node("%Tab" + t).pressed.connect(set_tab.bind(t.to_lower()))
	%Pull1.pressed.connect(pull.bind(1))
	%Pull10.pressed.connect(pull.bind(10))
	%AdPull.pressed.connect(_ad_pull)
	%Spark1.pressed.connect(pull_sparkle.bind(1))
	%Spark10.pressed.connect(pull_sparkle.bind(10))
	%Pity.pressed.connect(_pity)
	%Odds.pressed.connect(show_odds)
	%Restore.pressed.connect(_restore)
	%OddsClose.pressed.connect(%OddsPanel.hide)
	%Back.pressed.connect(back)
	AppFx.bob.call_deferred(%Capsule, 6.0)  # 웹 캡슐 둥실 (bob 1.6s)
	%OddsPanel.hide()
	AppState.meta().product_granted.connect(func(_k, _g): _refresh())
	_fill_store()
	set_tab(AppState.args().get("tab", "capsule"))


func set_tab(t: String) -> void:
	tab = t
	for name in ["Capsule", "Sparkle", "Store"]:
		get_node("%Tab" + name).set_pressed_no_signal(name.to_lower() == t)
		get_node("%" + name + "Page").visible = name.to_lower() == t
	%Bg.texture = load(BG[t])
	%Odds.visible = t != "store"
	_clear_prizes("캡슐을 돌려 봐" if t == "capsule" else "반짝 스티커를 뽑아 봐" if t == "sparkle" else "")
	_refresh()


func _clear_prizes(note: String) -> void:
	for c in %Prizes.get_children():
		c.queue_free()
	%PrizeNote.text = note
	%PrizeNote.visible = note != ""


func _show_prizes(prizes: Array, lack: String) -> void:
	_clear_prizes(lack if prizes.is_empty() else "%d개 나왔어!" % prizes.size())
	for p in prizes:
		var icon: FriendIcon = FRIEND_ICON.instantiate()
		%Prizes.add_child(icon)
		match p.kind:
			"new":
				icon.show_friend(p.id, 1)
				icon.set_badge("NEW!")
			"shard":
				icon.show_friend(p.id, 0, "조각 +%d" % int(p.n))
			"wild":
				icon.show_friend(p.id, 0, "만능 조각 +%d" % int(p.n))
			"max":
				icon.show_friend(p.id, 0, "코인 +%d" % int(p.coins))
		if p.get("pickup", false):
			icon.set_badge("픽업!")
	if prizes.any(func(p): return int(p.get("tier", 0)) >= 3):
		AppSound.sfx("gacha_rare")
	elif not prizes.is_empty():
		AppSound.sfx("gacha_reveal" if prizes.any(func(p): return p.kind == "new") else "gacha_roll")


func pull(k: int) -> Array:
	var prizes := AppState.meta().pull(k)
	_show_prizes(prizes, "코인이 모자라")
	_refresh()
	return prizes


func pull_sparkle(k: int) -> Array:
	var prizes := AppState.meta().pull_sparkle(k)
	_show_prizes(prizes, "별가루가 모자라 · 상점에서 살 수 있어")
	_refresh()
	return prizes


func _pity() -> void:
	var p := AppState.meta().pity_exchange()
	if not p.is_empty():
		_show_prizes([p], "")
	_refresh()


## 광고를 다 보면 메타가 코인 캡슐 티켓 1장을 줌 → 1번 뽑기 (Meta.pull은 티켓부터 씀)
func _ad_pull() -> void:
	if await AppAds.watch("free_gacha"):
		pull(1)


func _refresh() -> void:
	var m := AppState.meta()
	var look := FriendLook.shared()
	var g: Dictionary = m.cfg.economy.gacha
	%Pull1.text = "1번 · 티켓 1장" if m.data.tickets > 0 else "1번 · 코인 %d" % int(g.cost)
	%Pull1.disabled = m.data.tickets <= 0 and m.data.coins < int(g.cost)
	%Pull10.text = "10번 · 코인 %d" % int(g.cost10)
	%Pull10.disabled = m.data.coins < int(g.cost10)
	%AdPull.text = "광고 보고 1번 무료 (오늘 %d번)" % AppAds.left("free_gacha")
	%AdPull.disabled = not AppAds.can("free_gacha")
	var lines := []
	for f in m.cfg.friends.friends:
		if m.owned(f.id):
			var cost := m.up_cost(f.id)
			lines.append("%s  %d%s" % [look.name_of(f.id), int(m.data.shards.get(f.id, 0)), "" if cost.is_empty() else " / %d" % cost.shards])
	%Shards.text = "\n".join(PackedStringArray(lines))
	# 반짝 뽑기
	var pu := m.pickup()
	%Pickup.visible = pu != ""
	if pu != "":
		%Pickup.show_friend(pu, m.lv(pu))
		%Pickup.set_badge("픽업")
		%PickupText.text = "픽업 %s %d성\n3성이 나오면 %s 확률로 %s" % [look.name_of(pu), look.tier(pu), m.sparkle_rates().pickup_share, look.name_of(pu)]
	var need := int(m.cfg.gacha.sparkle.pity_stamps)
	%Stamps.max_value = need
	%Stamps.value = mini(int(m.data.stamps), need)
	%StampText.text = "별 도장 %d / %d" % [int(m.data.stamps), need]
	%Pity.disabled = not m.can_pity()
	%Pity.text = "도장 %d개로 %s 받기" % [need, look.name_of(pu)] if pu != "" else "픽업 없음"
	var c1 := m.sparkle_cost(1)
	%Spark1.text = "1번 · 반짝 티켓" if c1 == 0 else "1번 · 별가루 %d" % c1
	%Spark1.disabled = c1 > m.dust()
	var c10 := m.sparkle_cost(10)
	%Spark10.text = "10번 · 별가루 %d%s" % [c10, " (처음 반값!)" if c10 < int(m.cfg.gacha.sparkle.cost10) else ""]
	%Spark10.disabled = c10 > m.dust()
	# 상점
	var prices := Platform.billing().products()
	for b: Button in %Products.get_children():
		var key: String = b.get_meta("key")
		b.disabled = not m.can_buy(key) or not Platform.billing().is_ready()
		b.text = "%s\n%s\n%s" % [PRODUCT_NAME.get(key, key), describe(key), prices.get(key, {}).get("price_text", _krw(key))]
	%StoreNote.text = "" if Platform.billing().is_ready() else "지금은 스토어에 연결할 수 없어"
	%TopBar.refresh()


func _fill_store() -> void:
	for key in AppState.meta().cfg.products.products:
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 24)
		b.set_meta("key", key)
		b.pressed.connect(_ask_buy.bind(key))
		%Products.add_child(b)


## 상품에 든 것 (products.json)
static func describe(key: String) -> String:
	var pr: Dictionary = MetaConfig.shared().products.products.get(key, {})
	var parts := []
	if pr.has("dust"):
		parts.append("별가루 %d" % int(pr.dust) + (" + 첫 구매 %d" % int(pr.first_bonus) if pr.has("first_bonus") else ""))
	if pr.has("sparkle_tickets"):
		parts.append("반짝 티켓 %d" % int(pr.sparkle_tickets))
	if pr.has("monthly_days"):
		parts.append("%d일 매일 별가루 %d" % [int(pr.monthly_days), int(MetaConfig.shared().products.monthly.daily_dust)])
	if pr.get("growth_pack", false):
		parts.append("장을 깰 때마다 별가루")
	if pr.get("season_pass", false):
		parts.append("시즌 보상 칸")
	if pr.get("no_ads", false):
		parts.append("광고 보상을 바로")
	return " · ".join(PackedStringArray(parts))


## 결제 지급 쪽지 글 (AppRunner가 결제를 지급한 뒤)
static func describe_got(got: Dictionary) -> String:
	var parts := []
	if got.has("dust"):
		parts.append("별가루 %d" % int(got.dust))
	if got.has("bonus"):
		parts.append("보너스 %d" % int(got.bonus))
	if got.has("sparkle_tickets"):
		parts.append("반짝 티켓 %d" % int(got.sparkle_tickets))
	if got.has("monthly_until"):
		parts.append("스티커북 %s까지" % got.monthly_until)
	for k in GOT_NAME:
		if got.has(k):
			parts.append(GOT_NAME[k])
	return ", ".join(PackedStringArray(parts))


func _krw(key: String) -> String:
	return "₩%d" % int(StoreIds.PRODUCTS.get(key, {}).get("price_krw", 0))


func _ask_buy(key: String) -> void:
	var price: String = Platform.billing().products().get(key, {}).get("price_text", _krw(key))
	AppState.runner().layer.ask("%s\n%s\n\n%s" % [PRODUCT_NAME.get(key, key), price, REFUND_NOTE], "결제", Platform.billing().buy.bind(key))


func _restore() -> void:
	Platform.billing().restore()
	AppState.toast("산 것을 다시 확인하는 중…")


## 확률 보기 (게임산업법): 지금 탭의 뽑기
func show_odds() -> void:
	var m := AppState.meta()
	var look := FriendLook.shared()
	var lines := []
	if tab == "sparkle":
		var r := m.sparkle_rates()
		lines.append("등급 확률: 3성 %s · 2성 %s · 1성 %s" % [r.tier_rates.get("3", "-"), r.tier_rates.get("2", "-"), r.tier_rates.get("1", "-")])
		lines.append("10번 뽑기의 10번째 칸: 3성 %s · 2성 %s" % [r.ten_last_tier_rates.get("3", "-"), r.ten_last_tier_rates.get("2", "-")])
		if r.pickup != "":
			lines.append("픽업 %s: 3성이 나오면 %s" % [look.name_of(r.pickup), r.pickup_share])
		lines.append("별 도장 %d개 = 픽업 3성 바로 교환 (도장은 픽업이 바뀌어도 남아)" % int(r.pity_stamps))
		lines.append("")
		lines.append("친구마다 (1번 뽑기)")
		for row in r.per_pull:
			lines.append("%d성 %s  %s%s" % [int(row.tier), look.name_of(row.id), row.rate, "  픽업" if row.pickup else ""])
	else:
		var pool := m.gacha_pool()
		lines.append("캡슐 1번에 아래 친구 중 하나가 같은 확률로 나와.")
		lines.append("")
		for id in pool:
			lines.append("%s  %.2f%%" % [look.name_of(id), 100.0 / pool.size()])
		lines.append("")
		lines.append("10번 뽑기: 아직 없는 친구가 있으면 그중 1명 보장")
		lines.append("가진 친구가 또 나오면 조각 %d개 (최고 레벨이면 코인 %d)" % [int(m.cfg.economy.upgrade.shards_per_dup), int(m.cfg.economy.gacha.max_level_dup_coins)])
	%OddsText.text = "\n".join(PackedStringArray(lines))
	%OddsPanel.show()
	var p: Control = %Panel
	p.modulate.a = 0.0
	await get_tree().process_frame
	AppFx.pop_small(p)


func back() -> void:
	if %OddsPanel.visible:
		%OddsPanel.hide()
	else:
		AppState.go("map")
