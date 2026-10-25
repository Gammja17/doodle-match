extends RefCounted
## 반짝 뽑기(별가루) 확률표. 뽑기도 확률 공개도 이 표 하나로 셈 → 화면·홈페이지 숫자와 실제 뽑기가 어긋나지 않음.
## 숫자는 data/gacha.json sparkle (docs/design/tiers.md §4, docs/release/probability.md).
##   한 번마다: rates 등급 확률을 그 등급 친구들에게 똑같이 나눔
##   10회 뽑기의 10번째 칸: ten_last_rates (★2 이상만)
##   픽업이 있으면 ★3 몫의 pickup_share는 픽업 친구, 나머지는 픽업이 아닌 상시 ★3에게 똑같이
## Meta가 preload해서 씀 (class_name 없음: 새 클래스 목록 갱신 없이 돌게).


## 친구마다 확률 [{ id, tier, rate, pickup }]. last면 10번째 칸 표. 합은 1
static func table(sp: Dictionary, pickup: String, last := false) -> Array:
	var rates: Dictionary = sp.ten_last_rates if last else sp.rates
	var out := []
	for t in ["3", "2", "1"]:
		var p := float(rates.get(t, 0.0))
		if p <= 0.0:
			continue
		var pool: Array = sp.pool[t].duplicate()
		if t == "3" and pickup != "":
			pool.erase(pickup)
			var share: float = sp.pickup_share if not pool.is_empty() else 1.0
			out.append({id = pickup, tier = 3, rate = p * share, pickup = true})
			p *= 1.0 - share
		for id in pool:
			out.append({id = id, tier = int(t), rate = p / pool.size(), pickup = false})
	return out


## 한 번 뽑기 → { id, tier, pickup }
static func draw(sp: Dictionary, pickup: String, rng: RandomNumberGenerator, last := false) -> Dictionary:
	var rows := table(sp, pickup, last)
	var r := rng.randf()
	for row in rows:
		r -= row.rate
		if r < 0.0:
			return row
	return rows[-1]  # 실수 끝자리로 합이 1보다 조금 작을 때


## 확률 공개용 (게임 안 "확률 보기"·홈페이지가 같이 씀). 확률은 % 글자, 소수 셋째 자리까지
static func disclosure(sp: Dictionary, banner: Dictionary) -> Dictionary:
	var pickup: String = banner.get("pickup", "")
	return {
		banner = banner.get("id", ""),
		pickup = pickup,
		cost = {one = int(sp.cost), ten = int(sp.cost10), first_ten = int(sp.first10_cost)},
		tier_rates = _pct_map(sp.rates),
		ten_last_tier_rates = _pct_map(sp.ten_last_rates),
		pickup_share = _pct(sp.pickup_share),
		pity_stamps = int(sp.pity_stamps),
		per_pull = _pct_rows(table(sp, pickup)),
		ten_last = _pct_rows(table(sp, pickup, true)),
	}


static func _pct(x: float) -> String:
	return "%.3f%%" % (x * 100.0)


static func _pct_map(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = _pct(d[k])
	return out


static func _pct_rows(rows: Array) -> Array:
	return rows.map(func(r): return {id = r.id, tier = r.tier, pickup = r.pickup, rate = _pct(r.rate)})
