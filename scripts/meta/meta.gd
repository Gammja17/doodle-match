class_name Meta
extends RefCounted










signal aff_level_up(id: String, lv: int)
signal product_granted(key: String, got: Dictionary)
signal saved

const Sparkle: = preload("res://scripts/meta/sparkle_gacha.gd")
const DAY_MS: = 86400000

var cfg: MetaConfig
var data: Dictionary
var rng: = RandomNumberGenerator.new()
var clock: Callable
var save_path: = SaveStore.PATH
var read_only: = false
var load_info: = {}


func _init(config: MetaConfig = null, save: = {}) -> void :
	cfg = config if config else MetaConfig.shared()
	data = save if not save.is_empty() else SaveStore.fresh(cfg)
	clock = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)
	rng.randomize()
	_mark_start()


static func load_game(path: = SaveStore.PATH) -> Meta:
	var m: = Meta.new()
	m.save_path = path
	var r: = SaveStore.load_ex(m.cfg, path)
	m.data = r.data
	r.erase("data")
	m.load_info = r
	m.read_only = r.too_new
	m._mark_start()
	return m



func _mark_start() -> void :
	if int(data.get("started_at", 0)) == 0:
		data.started_at = now()
	if String(data.get("device_id", "")) == "":
		data.device_id = "%08x" % rng.randi()


func save() -> bool:
	if read_only:
		return false
	data.saved_at = now()
	var ok: = SaveStore.save_to(data, save_path)
	if ok:
		saved.emit()
	return ok




func reset() -> void :
	data = SaveStore.fresh(cfg)
	read_only = false
	_mark_start()
	if save_path != "":
		for p in [save_path, save_path + ".bak1", save_path + ".bak2", save_path + ".bak"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
		save()


func _changed() -> void :
	if save_path != "":
		save()




func now() -> int:
	return clock.call()


func today() -> String:
	return Time.get_date_string_from_unix_time(now() / 1000)


static func day_no(day: String) -> int:
	return Time.get_unix_time_from_datetime_string(day) / 86400




func add_coins(n: int) -> void :
	data.coins += n
	_changed()


func treat_n(t: String) -> int:
	return int(data.treats.get(t, 0))


func _add_treat(t: String, n: int) -> void :
	data.treats[t] = treat_n(t) + n





func _give(r: Dictionary) -> void :
	data.coins += int(r.get("coins", 0))
	data.tickets += int(r.get("tickets", 0))
	data.dust.free = int(data.dust.free) + int(r.get("dust", 0))
	data.sparkle_tickets += int(r.get("sparkle_tickets", 0))
	data.crayons += int(r.get("crayons", 0))
	if r.has("treat"):
		_add_treat(r.treat, int(r.count))
	for t in r.get("treats", {}):
		_add_treat(t, int(r.treats[t]))
	for k in ["wild", "pick", "items"]:
		var add: Dictionary = r.get(k, {})
		for x in add:
			data[k][x] = int(data[k].get(x, 0)) + int(add[x])
	if r.has("outfit"):
		var o: Dictionary = r.outfit
		if not data.outfits.has(o.friend):
			data.outfits[o.friend] = []
		if not o.id in data.outfits[o.friend]:
			data.outfits[o.friend].append(o.id)



func cleared_count() -> int:
	return data.stars.keys().filter( func(ref): return cfg.route_n.has(ref)).size()



func is_open(feature: String) -> bool:
	return cleared_count() >= int(cfg.extra.unlocks.get(feature, 0))




func lv(id: String) -> int:
	return int(data.own.get(id, 0))


func owned(id: String) -> bool:
	return lv(id) > 0



func max_lv(id: String) -> int:
	return int(cfg.economy.upgrade.lv_max) + int(data.overpaint.get(id, 0))



func top_lv(id: String) -> int:
	var t: = cfg.tier(id)
	return int(cfg.economy.upgrade.lv_max) + (int(cfg.gacha.growth.overpaint_max[str(t)]) if t > 0 else 0)



func lv_mult(id: String, at: = -1) -> float:
	var u: Dictionary = cfg.economy.upgrade
	var per: float = u.power_per_lv_treat_friend if cfg.is_treat_friend(id) else u.power_per_lv
	return 1.0 + per * maxi(0, (lv(id) if at < 0 else at) - 1)



func mult(id: String) -> float:
	var m: = lv_mult(id)
	var o: = cfg.outfit(data.wearing.get(id, ""))
	if not o.is_empty() and not o.get("paid", false):
		m *= cfg.economy.upgrade.outfit_mult
	m *= 1.0 + data.train.atk * cfg.economy.training.atk_pct_per_lv / 100.0
	if aff_lv(id) >= int(cfg.extra.affection.best_lv):
		m *= cfg.extra.affection.best_mult
	return m



func power(id: String, at: = -1) -> float:
	var f: Dictionary = cfg.friend_by_id[id]
	var m: = mult(id) / lv_mult(id) * lv_mult(id, at)
	if f.has("heal"):
		return roundf(f.heal * m * 10.0) / 10.0
	return roundf(f.dmg * m)




func up_cost(id: String) -> Dictionary:
	var u: Dictionary = cfg.economy.upgrade
	var l: = lv(id)
	if l >= max_lv(id):
		return {}
	var t: String = cfg.recruit_by_id[id].treat if cfg.is_treat_friend(id) else ""
	var need: = int(u.shard_need[mini(l, u.shard_need.size() - 1)])
	return {shards = need, coins = l * int(u.coins_per_lv), treat = t, treat_n = l * int(u.treat_per_lv) if t != "" else 0}


func can_up(id: String) -> bool:
	var c: = up_cost(id)
	return owned(id) and not c.is_empty() and int(data.shards.get(id, 0)) >= c.shards\
	and data.coins >= c.coins and (c.treat == "" or treat_n(c.treat) >= c.treat_n)


func level_up(id: String) -> bool:
	if not can_up(id):
		return false
	var c: = up_cost(id)
	data.shards[id] = int(data.shards[id]) - c.shards
	data.coins -= c.coins
	if c.treat != "":
		_add_treat(c.treat, - c.treat_n)
	data.own[id] = lv(id) + 1
	_changed()
	return true




func _join(id: String) -> void :
	data.own[id] = 1
	data.join_at[id] = cleared_count()



func can_recruit(id: String) -> bool:
	var pid: = cfg.play_id(id)
	var r: Dictionary = cfg.recruit_by_id.get(pid, {})
	return r.get("by") == "treat" and not owned(pid) and treat_n(r.treat) >= int(r.count)




func recruit(id: String) -> bool:
	var pid: = cfg.play_id(id)
	if owned(pid):
		return false
	var r: Dictionary = cfg.recruit_by_id.get(pid, {})
	if r.get("by") == "treat":
		if not can_recruit(pid):
			return false
		_add_treat(r.treat, - int(r.count))
	_join(pid)
	_changed()
	return true




func due_joins() -> Array:
	var due: = []
	for id in cfg.recruit_by_id:
		var r: Dictionary = cfg.recruit_by_id[id]
		if owned(id):
			continue
		match r.by:
			"clear":
				if data.stars.has(cfg.route_ref.get(int(r.route), "")):
					due.append(id)
			"after":
				if owned(r.friend_after) and cleared_count() >= int(data.join_at.get(r.friend_after, 0)) + int(r.clears):
					due.append(id)
	return due





func gacha_pool() -> Array:
	return cfg.friends.friends.map( func(f): return f.id).filter( func(id): return not cfg.recruit_by_id.has(id) or owned(id))


func wish_id() -> String:
	var w: String = data.wish
	return w if w in gacha_pool() and lv(w) < top_lv(w) else ""


func set_wish(id: String) -> bool:
	if not id in gacha_pool() or lv(id) >= top_lv(id):
		return false
	data.wish = id
	_changed()
	return true





func pull(n: int) -> Array:
	assert (n == 1 or n == 10)
	var g: Dictionary = cfg.economy.gacha
	var ticket: bool = n == 1 and data.tickets > 0
	var cost: = 0 if ticket else int(g.cost10 if n == 10 else g.cost)
	if data.coins < cost:
		return []
	if ticket:
		data.tickets -= 1
	data.coins -= cost
	mission_add("gacha", n)
	var prizes: = []
	var wish: = wish_id() if n == 10 else ""
	if wish != "":
		prizes.append(_draw(false, wish))
	while prizes.size() < n - 1:
		prizes.append(_draw())
	var sure: = n == 10 and int(g.ten_guarantees_new) > 0 and not prizes.any( func(p): return p.kind == "new")
	prizes.append(_draw(sure))
	for i in range(prizes.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var t = prizes[i]
		prizes[i] = prizes[j]
		prizes[j] = t
	_changed()
	return prizes


func _draw(sure: = false, force: = "") -> Dictionary:
	var all: = gacha_pool()
	var fresh: = all.filter( func(x): return not owned(x))
	var from: = fresh if sure and not fresh.is_empty() else all
	var id: String = force if force != "" else from[rng.randi_range(0, from.size() - 1)]
	var g: Dictionary = cfg.economy.gacha
	var u: Dictionary = cfg.economy.upgrade
	if not owned(id):
		_join(id)
		return {kind = "new", id = id}
	if lv(id) < top_lv(id):
		data.shards[id] = int(data.shards.get(id, 0)) + int(u.shards_per_dup)
		return {kind = "shard", id = id, n = int(u.shards_per_dup)}
	data.coins += int(g.max_level_dup_coins)
	return {kind = "max", id = id, coins = int(g.max_level_dup_coins)}




func has_outfit(oid: String) -> bool:
	var o: = cfg.outfit(oid)
	return not o.is_empty() and oid in data.outfits.get(o.friend, [])



func buy_outfit(oid: String) -> bool:
	var o: = cfg.outfit(oid)
	if o.is_empty() or not owned(o.friend) or has_outfit(oid) or data.coins < int(o.price):
		return false
	data.coins -= int(o.price)
	if not data.outfits.has(o.friend):
		data.outfits[o.friend] = []
	data.outfits[o.friend].append(oid)
	data.wearing[o.friend] = oid
	_changed()
	return true


func wear_outfit(oid: String) -> bool:
	if not has_outfit(oid):
		return false
	data.wearing[cfg.outfit(oid).friend] = oid
	_changed()
	return true





func stage_treat(ref: String) -> String:
	var st: Dictionary = cfg.economy.stage_treat
	var i: = int(ref.substr(1)) - 1 + (int(st.battle_offset) if ref.begins_with("b") else 0)
	return st.rotation[i % st.rotation.size()]



func stage_coins(stars: int, first: bool) -> int:
	var c: Dictionary = cfg.economy.stage_clear
	return int(c.first_base) + stars * int(c.first_per_star) if first else stars * int(c.repeat_per_star)

















func finish_stage(result: Dictionary) -> Dictionary:
	var out: = {coins = 0}
	var counts: Dictionary = result.get("counts", {})
	for k in counts:
		mission_add(k, int(counts[k]))
	match result.kind:
		"route":
			_finish_route(result, out)
		"daily":
			_finish_daily(result, out)
		"vault", "snack_vault":
			_finish_vault(result, out, result.kind == "snack_vault")
		"shard_dungeon":
			_finish_dungeon(result, out)
	_changed()
	return out


func _finish_route(r: Dictionary, out: Dictionary) -> void :
	if not r.won:
		out.heart_lost = lose_heart()
		return
	var ref: String = r.ref
	var stars: = int(r.stars)
	var first: bool = not data.stars.has(ref)
	out.first = first
	out.stars = stars
	out.coins = stage_coins(stars, first)
	data.coins += out.coins
	var st: Dictionary = cfg.economy.stage_treat
	out.treat = {id = stage_treat(ref), n = int(st.first_3star if first and stars == 3 else st.otherwise)}
	_add_treat(out.treat.id, out.treat.n)
	mission_add("win")
	if ref.begins_with("b"):
		mission_add("battle")
	var attrs: = []
	for id in _unique(r.get("team", [])):
		aff_add(id, int(cfg.extra.affection.win))
		if cfg.attr(id) != "" and not cfg.attr(id) in attrs:
			attrs.append(cfg.attr(id))
	for a in attrs:
		mission_add("win_with:" + a)
	season_add_xp(int(cfg.live.season.route_win_xp))
	var ev: = _event_drop(stars)
	if not ev.is_empty():
		out.event = ev
	if first and ref.begins_with("b"):
		data.free_bowl = int(data.free_bowl) + 1
		out.free_bowl = true
	data.stars[ref] = maxi(int(data.stars.get(ref, 0)), stars)
	if not first:
		return
	var mvp: String = r.get("mvp", "")
	if owned(mvp) and lv(mvp) < top_lv(mvp):
		data.shards[mvp] = int(data.shards.get(mvp, 0)) + stars
		out.shards = {id = mvp, n = stars}


func _unique(a: Array) -> Array:
	var u: = []
	for x in a:
		if not x in u:
			u.append(x)
	return u




func _sync_hearts() -> void :
	var h: Dictionary = cfg.economy.hearts
	var t: = now()
	if data.hearts >= int(h.max):
		data.heart_at = t
		return
	var n: = (t - int(data.heart_at)) / int(h.refill_ms)
	if n > 0:
		data.hearts = mini(int(h.max), data.hearts + n)
		data.heart_at = t if data.hearts >= int(h.max) else int(data.heart_at) + n * int(h.refill_ms)


func hearts() -> int:
	_sync_hearts()
	return data.hearts



func heart_wait_ms() -> int:
	if hearts() >= int(cfg.economy.hearts.max):
		return 0
	return maxi(0, int(cfg.economy.hearts.refill_ms) - (now() - int(data.heart_at)))


func unlimited() -> bool:
	return int(data.unlimited_until) > now()


func can_enter() -> bool:
	return hearts() > 0 or unlimited()



func lose_heart() -> bool:
	if unlimited():
		return false
	_sync_hearts()
	if data.hearts >= int(cfg.economy.hearts.max):
		data.heart_at = now()
	data.hearts = maxi(0, data.hearts - 1)
	_changed()
	return true


func add_hearts(k: int) -> void :
	_sync_hearts()
	data.hearts = mini(int(cfg.economy.hearts.max), data.hearts + k)
	if data.hearts >= int(cfg.economy.hearts.max):
		data.heart_at = now()
	_changed()



func refill_hearts() -> bool:
	var h: Dictionary = cfg.economy.hearts
	if data.coins < int(h.refill_all_coins):
		return false
	data.coins -= int(h.refill_all_coins)
	data.hearts = int(h.max)
	data.heart_at = now()
	_changed()
	return true


func start_unlimited() -> void :
	data.unlimited_until = maxi(now(), int(data.unlimited_until)) + int(cfg.economy.hearts.unlimited_ms)
	_changed()




func item_n(id: String) -> int:
	return int(data.items.get(id, 0))


func buy_item(id: String) -> bool:
	var it: = {}
	for s in cfg.economy.shop:
		if s.id == id:
			it = s
	if it.is_empty() or data.coins < int(it.price):
		return false
	data.coins -= int(it.price)
	data.items[id] = item_n(id) + 1
	_changed()
	return true



func use_item(id: String) -> bool:
	if item_n(id) < 1:
		return false
	data.items[id] = item_n(id) - 1
	match id:
		"heart1":
			add_hearts(1)
		"heart_unlimited30m":
			start_unlimited()
	_changed()
	return true






func attend() -> int:
	var day: = today()
	if data.att.day == day:
		return -1
	var at: Dictionary = cfg.live.attendance
	if data.att.n >= int(at.cycle_days):
		data.att.n = 0
		data.att.cycles = int(data.att.get("cycles", 0)) + 1
	var k: int = data.att.n
	data.att.n = k + 1
	data.att.day = day
	for r in attend_rewards(k):
		_give(r)
	missions()
	_changed()
	return k



func attend_rewards(k: int) -> Array:
	var at: Dictionary = cfg.live.attendance
	var out: Array = [at.week[k % at.week.size()]]
	if at.month.has(str(k + 1)):
		out.append(at.month[str(k + 1)])
	if k == at.week.size() - 1 and int(data.att.get("cycles", 0)) == 0:
		out.append(at.first_week_extra)
	return out




func missions_on() -> bool:
	return cleared_count() >= int(cfg.economy.missions.unlock_clears)


func _mission(id: String) -> Dictionary:
	for m in cfg.economy.missions.list:
		if m.id == id:
			return m
	return {}



func missions() -> Dictionary:
	var day: = today()
	if data.mis.get("day") == day:
		return data.mis
	var pool: Array = cfg.economy.missions.list.filter( func(m): return not m.has("need") or is_open(m.need))
	var rnd: = DaySeed.new(day)
	var ids: = []
	while ids.size() < int(cfg.extra.missions.per_day):
		var id: String = pool[floori(rnd.next() * pool.size())].id
		if not id in ids:
			ids.append(id)
	data.mis = {day = day, ids = ids, got = {}, done = {}, bonus = false}
	return data.mis



func mission_add(id: String, n: = 1) -> void :
	if n <= 0 or not missions_on():
		return
	_weekly_add(id, n)
	var ms: = missions()
	if not id in ms.ids or ms.done.get(id, false):
		return
	ms.got[id] = mini(int(_mission(id).n), int(ms.got.get(id, 0)) + n)



func mission_claim(id: String) -> bool:
	var ms: = missions()
	if not id in ms.ids or ms.done.get(id, false) or int(ms.got.get(id, 0)) < int(_mission(id).n):
		return false
	ms.done[id] = true
	data.coins += int(cfg.economy.missions.coins)
	season_add_xp(int(cfg.live.daily_missions.xp))
	_changed()
	return true



func mission_bonus_claim() -> bool:
	var ms: = missions()
	if ms.bonus or not ms.ids.all( func(id): return ms.done.get(id, false)):
		return false
	ms.bonus = true
	_give(cfg.live.daily_missions.bonus)
	season_add_xp(int(cfg.live.daily_missions.bonus_xp))
	_changed()
	return true





static func week_no(day: String) -> int:
	return floori((day_no(day) + 3) / 7.0)



func weekly() -> Dictionary:
	var w: = week_no(today())
	if int(data.weekly.week) != w:
		data.weekly = {week = w, got = {}, done = {}, bonus = false}
	return data.weekly



func weekly_list() -> Array:
	var w: = week_no(today())
	return cfg.live.weekly_missions.list.map( func(m):
		var x: Dictionary = m.duplicate()
		if m.has("attr_rotate"):
			x.k = "%s:%s" % [m.k, m.attr_rotate[posmod(w, m.attr_rotate.size())]]
		return x)


func _weekly_add(k: String, n: int) -> void :
	var wk: = weekly()
	for m in weekly_list():
		if m.k == k and not wk.done.get(m.id, false):
			wk.got[m.id] = mini(int(m.n), int(wk.got.get(m.id, 0)) + n)


func weekly_claim(id: String) -> bool:
	var wk: = weekly()
	var list: = weekly_list().filter( func(m): return m.id == id)
	if list.is_empty() or wk.done.get(id, false) or int(wk.got.get(id, 0)) < int(list[0].n):
		return false
	wk.done[id] = true
	_give(list[0].reward)
	season_add_xp(int(cfg.live.weekly_missions.xp))
	_changed()
	return true


func weekly_bonus_claim() -> bool:
	var wk: = weekly()
	if wk.bonus or not weekly_list().all( func(m): return wk.done.get(m.id, false)):
		return false
	wk.bonus = true
	_give(cfg.live.weekly_missions.bonus)
	_changed()
	return true





func daily_stage(day: = "") -> Dictionary:
	if day == "":
		day = today()
	return DaySeed.daily_stage(cfg.modes.daily_challenge, day, day_no(day))


func daily_done() -> bool:
	return data.dch.day == today() and data.dch.done



func daily_treat(day: = "") -> String:
	var rot: Array = cfg.economy.daily_challenge.treat_rotation
	return rot[posmod(day_no(day if day != "" else today()), rot.size())]


func _finish_daily(r: Dictionary, out: Dictionary) -> void :
	if not r.won:
		return
	if daily_done():
		out.repeat = true
		return
	var dc: Dictionary = cfg.economy.daily_challenge
	data.dch = {day = today(), done = true}
	out.coins = int(dc.coins)
	data.coins += out.coins
	out.treat = {id = daily_treat(), n = int(dc.treats)}
	_add_treat(out.treat.id, out.treat.n)
	mission_add("dchal")




func vault_left(snack: = false) -> int:
	var rec: Dictionary = data.snack_vault if snack else data.vault
	var extra: int = data.vault_extra.n if not snack and data.vault_extra.day == today() else 0
	return int(cfg.economy.vault.daily) + extra - (int(rec.n) if rec.day == today() else 0)



func vault_hit_coins(broken: bool) -> int:
	var c: Dictionary = cfg.economy.vault.coins
	return int(c.sticky_broken if broken else c.double_sticky_hit)



func vault_refill_coins() -> int:
	return int(cfg.economy.vault.coins.refill)


func set_snack_pick(t: String) -> void :
	data.snack_pick = t
	_changed()



func _finish_vault(r: Dictionary, out: Dictionary, snack: bool) -> void :
	if not r.won or vault_left(snack) <= 0:
		return
	var key: = "snack_vault" if snack else "vault"
	var rec: Dictionary = data[key]
	data[key] = {day = today(), n = (int(rec.n) if rec.day == today() else 0) + 1}
	var total: = int(r.get("vault_coins", 0)) + int(r.get("score", 0)) / int(cfg.extra.vault.score_per_bonus_coin)
	if not snack:
		out.coins = total
		data.coins += total
		mission_add("vault")
		return
	var sv: Dictionary = cfg.economy.snack_vault
	out.treat = {id = data.snack_pick, n = maxi(int(sv.min_treats), roundi(float(total) / sv.coins_per_treat))}
	_add_treat(out.treat.id, out.treat.n)




func aff_pts(id: String) -> int:
	return int(data.aff.get(id, 0))



func aff_lv(id: String) -> int:
	return cfg.extra.affection.at.filter( func(n): return aff_pts(id) >= n).size()


func aff_add(id: String, n: int) -> void :
	if not owned(id) or n <= 0:
		return
	var a: Dictionary = cfg.extra.affection
	var before: = aff_lv(id)
	data.aff[id] = mini(int(a.at[-1]), aff_pts(id) + n)
	for l in range(before + 1, aff_lv(id) + 1):
		_give(a.rewards.get(str(l), {}))
		aff_level_up.emit(id, l)
	_changed()


func can_pat(id: String) -> bool:
	return owned(id) and data.pat.get(id) != today()



func pat(id: String) -> bool:
	if not can_pat(id):
		return false
	data.pat[id] = today()
	mission_add("pat")
	aff_add(id, int(cfg.extra.affection.pat))
	_changed()
	return true



func feed(id: String, t: String) -> bool:
	if not owned(id) or treat_n(t) < 1:
		return false
	_add_treat(t, -1)
	var a: Dictionary = cfg.extra.affection
	aff_add(id, int(a.feed_fav if a.fav.get(id) == t else a.feed))
	_changed()
	return true





func train_cap() -> int:
	var tr: Dictionary = cfg.economy.training
	return mini(int(tr.max_lv), 1 + cleared_count() / int(tr.cap_per_clears))


func train_cost(id: String) -> int:
	var l: int = data.train[id]
	return int(cfg.economy.training.cost[l]) if l < int(cfg.economy.training.max_lv) else -1


func train_up(id: String) -> bool:
	var l: int = data.train[id]
	if l >= train_cap() or data.coins < train_cost(id):
		return false
	data.coins -= train_cost(id)
	data.train[id] = l + 1
	_changed()
	return true



func train_hp_bonus() -> int:
	return data.train.hp * int(cfg.economy.training.hp_per_lv)





func ramen_menu() -> Array:
	return cfg.economy.buffs.menu.filter( func(b): return b.mode == "battle")


func ramen_open(b: Dictionary) -> bool:
	return cleared_count() >= int(b.unlock_clears)


func _bowl(id: String) -> Dictionary:
	for b in cfg.economy.buffs.menu:
		if b.id == id:
			return b
	return {}




func eat(id: String) -> Dictionary:
	var b: = _bowl(id)
	if b.is_empty() or b.mode != "battle" or not ramen_open(b):
		return {ok = false, reason = "locked"}
	if data.buff != "":
		return {ok = false, reason = "has_buff"}
	var free: bool = int(data.free_bowl) > 0
	if not free and data.coins < int(b.price):
		return {ok = false, reason = "coins"}
	if free:
		data.free_bowl = int(data.free_bowl) - 1
	else:
		data.coins -= int(b.price)
	data.buff = id
	data.bowls = int(data.bowls) + 1
	var treat: = ""
	if data.bowls % int(cfg.economy.buffs.stamp_every) == 0:
		var g: = ramen_guest()
		var all: Array = cfg.economy.treats
		treat = g.treat if not g.is_empty() else all[rng.randi_range(0, all.size() - 1)]
		_add_treat(treat, 1)
	mission_add("buff")
	_changed()
	return {ok = true, free = free, treat = treat}




func take_battle_buff() -> Dictionary:
	var out: = {team_hp = int(cfg.rules.battle.team_hp), gauge_fill = 0.0, bowl = ""}
	var b: = _bowl(data.buff)
	if not b.is_empty() and b.mode == "battle":
		out.bowl = b.id
		out.team_hp = int(b.get("team_hp", out.team_hp))
		if b.get("gauge", "") == "half":
			out.gauge_fill = 0.5
		data.buff = ""
		_changed()
	out.team_hp += train_hp_bonus()
	return out




func ramen_guest() -> Dictionary:
	var best: = {}
	for id in cfg.recruit_by_id:
		var r: Dictionary = cfg.recruit_by_id[id]
		if r.by == "treat" and cfg.friend_by_id.has(id) and not owned(id) and (best.is_empty() or int(r.count) < best.count):
			best = {id = id, treat = r.treat, count = int(r.count), have = treat_n(r.treat)}
	return best



func start_items() -> Array:
	return cfg.economy.shop.filter( func(s): return s.has("put"))



func take_start_items() -> Array:
	var put: = []
	for s in start_items():
		if use_item(s.id):
			put.append_array(s.put)
	return put




func dust() -> int:
	return int(data.dust.paid) + int(data.dust.free)



func add_dust(n: int, paid: = false) -> void :
	var k: = "paid" if paid else "free"
	data.dust[k] = int(data.dust[k]) + n
	_changed()



func spend_dust(n: int) -> bool:
	if dust() < n:
		return false
	var f: = mini(n, int(data.dust.free))
	data.dust.free = int(data.dust.free) - f
	data.dust.paid = int(data.dust.paid) - (n - f)
	_changed()
	return true





func banner() -> Dictionary:
	var best: = {}
	for b in cfg.gacha.banners:
		if b.start <= today() and (best.is_empty() or b.start >= best.start):
			best = b
	return best


func pickup() -> String:
	return banner().get("pickup", "")



func sparkle_cost(n: int) -> int:
	var sp: Dictionary = cfg.gacha.sparkle
	if n == 1:
		return 0 if data.sparkle_tickets > 0 else int(sp.cost)
	return int(sp.cost10) if data.first10_used else int(sp.first10_cost)






func pull_sparkle(n: int) -> Array:
	assert (n == 1 or n == 10)
	if n == 1 and data.sparkle_tickets > 0:
		data.sparkle_tickets -= 1
	elif not spend_dust(sparkle_cost(n)):
		return []
	elif n == 10:
		data.first10_used = true
	var pu: = pickup()
	var prizes: = []
	for i in n:
		var row: = Sparkle.draw(cfg.gacha.sparkle, pu, rng, n == 10 and i == n - 1)
		var p: = _give_char(row.id)
		p.pickup = row.pickup
		_log(p)
		prizes.append(p)
	data.stamps += n
	mission_add("gacha", n)
	_changed()
	return prizes



func _give_char(id: String) -> Dictionary:
	var t: = cfg.tier(id)
	var n: = int(cfg.gacha.growth.dup_shards[str(t)])
	if not owned(id):
		_join(id)
		return {kind = "new", id = id, tier = t}
	if lv(id) < top_lv(id):
		data.shards[id] = int(data.shards.get(id, 0)) + n
		return {kind = "shard", id = id, tier = t, n = n}
	data.wild[str(t)] = int(data.wild[str(t)]) + n
	return {kind = "wild", id = id, tier = t, n = n}


func _log(p: Dictionary) -> void :
	data.gacha_log.append({at = now(), banner = banner().get("id", ""), id = p.id, kind = p.kind})
	while data.gacha_log.size() > int(cfg.gacha.log_max):
		data.gacha_log.pop_front()



func can_pity() -> bool:
	return pickup() != "" and data.stamps >= int(cfg.gacha.sparkle.pity_stamps)


func pity_exchange() -> Dictionary:
	if not can_pity():
		return {}
	data.stamps -= int(cfg.gacha.sparkle.pity_stamps)
	var p: = _give_char(pickup())
	p.pickup = true
	_log(p)
	_changed()
	return p



func sparkle_rates() -> Dictionary:
	return Sparkle.disclosure(cfg.gacha.sparkle, banner())





func can_overpaint(id: String) -> bool:
	var c: Dictionary = cfg.gacha.growth.overpaint_cost
	return cfg.tier(id) > 0 and owned(id) and lv(id) >= max_lv(id) and max_lv(id) < top_lv(id)\
	and int(data.shards.get(id, 0)) >= int(c.shards) and data.crayons >= int(c.crayons)


func overpaint(id: String) -> bool:
	if not can_overpaint(id):
		return false
	var c: Dictionary = cfg.gacha.growth.overpaint_cost
	data.shards[id] = int(data.shards[id]) - int(c.shards)
	data.crayons -= int(c.crayons)
	data.overpaint[id] = int(data.overpaint.get(id, 0)) + 1
	_changed()
	return true



func use_wild(id: String, n: int) -> bool:
	var t: = str(cfg.tier(id))
	if t == "0" or not owned(id) or n <= 0 or int(data.wild[t]) < n:
		return false
	data.wild[t] = int(data.wild[t]) - n
	data.shards[id] = int(data.shards.get(id, 0)) + n
	_changed()
	return true



func use_pick(id: String) -> Dictionary:
	var t: = str(cfg.tier(id))
	if int(data.pick.get(t, 0)) <= 0 or not id in cfg.gacha.sparkle.pool.get(t, []):
		return {}
	data.pick[t] = int(data.pick[t]) - 1
	var p: = _give_char(id)
	_changed()
	return p





func attach_billing(b: Billing) -> void :
	b.purchased.connect( func(p: Dictionary) -> void :
		if not already_granted(p.order_id):
			grant_product(p.key, p.order_id)
		b.finish(p))


func already_granted(order_id: String) -> bool:
	return data.purchases.has(order_id)



func can_buy(key: String) -> bool:
	var pr: Dictionary = cfg.products.products.get(key, {})
	if pr.is_empty() or (pr.get("once", false) and data.bought.has(key)) or (pr.get("no_ads", false) and data.no_ads):
		return false
	if pr.get("season_pass", false) and (season_info().is_empty() or season().paid):
		return false
	return not pr.has("sell_days") or now() < int(data.started_at) + int(pr.sell_days) * DAY_MS




func grant_product(key: String, order_id: String) -> Dictionary:
	var pr: Dictionary = cfg.products.products.get(key, {})
	if already_granted(order_id):
		return {}
	if pr.is_empty():
		push_warning("모르는 상품: %s (%s)" % [key, order_id])
		return {}
	var got: = {}
	if pr.has("dust"):
		got.dust = int(pr.dust)
		data.dust.paid = int(data.dust.paid) + got.dust
	if pr.has("first_bonus") and not data.bought.has(key):
		got.bonus = int(pr.first_bonus)
		data.dust.free = int(data.dust.free) + got.bonus
	if pr.has("sparkle_tickets"):
		got.sparkle_tickets = int(pr.sparkle_tickets)
		data.sparkle_tickets += got.sparkle_tickets
	if pr.has("monthly_days"):
		var from: = day_no(data.monthly.until) + 1 if monthly_active() else day_no(today())
		data.monthly.until = Time.get_date_string_from_unix_time((from + int(pr.monthly_days) - 1) * 86400)
		got.monthly_until = data.monthly.until
	if pr.get("season_pass", false):
		season().paid = true
		got.season_pass = true
	if pr.get("no_ads", false):
		data.no_ads = true
		got.no_ads = true
	if pr.get("growth_pack", false):
		data.growth.bought = true
		got.growth_pack = true
	data.bought[key] = int(data.bought.get(key, 0)) + 1
	data.purchases[order_id] = {key = key, at = now()}
	_changed()
	product_granted.emit(key, got)
	return got



func monthly_active() -> bool:
	return data.monthly.until != "" and data.monthly.until >= today()


func claim_monthly() -> bool:
	if not monthly_active() or data.monthly.last == today():
		return false
	var mo: Dictionary = cfg.products.monthly
	data.monthly.last = today()
	data.dust.paid = int(data.dust.paid) + int(mo.daily_dust)
	data.tickets += int(mo.daily_coin_tickets)
	_changed()
	return true



func chapters_cleared() -> int:
	return cfg.route.chapters.filter( func(ch): return data.stars.has(cfg.route_ref.get(int(ch.first) + int(ch.count) - 1, ""))).size()



func claim_growth() -> Array:
	if not data.growth.bought:
		return []
	var g: Dictionary = cfg.products.growth
	var got: = []
	for c in g.chapters:
		var ch: = int(c)
		if ch in data.growth.got or chapters_cleared() < ch:
			continue
		data.growth.got.append(ch)
		data.dust.paid = int(data.dust.paid) + int(g.dust_each)
		if ch == int(g.pick2_at):
			data.pick["2"] = int(data.pick["2"]) + 1
		got.append(ch)
	if not got.is_empty():
		_changed()
	return got




func ad_left(slot: String) -> int:
	var used: int = int(data.ads.n.get(slot, 0)) if data.ads.day == today() else 0
	return int(cfg.gacha.ads_daily.get(slot, 0)) - used





func ad_reward(slot: String, amount: = 0) -> bool:
	if ad_left(slot) <= 0:
		return false
	if data.ads.day != today():
		data.ads = {day = today(), n = {}}
	data.ads.n[slot] = int(data.ads.n.get(slot, 0)) + 1
	match slot:
		"heart":
			add_hearts(1)
		"free_gacha":
			data.tickets += 1
		"vault_again":
			if data.vault_extra.day != today():
				data.vault_extra = {day = today(), n = 0}
			data.vault_extra.n = int(data.vault_extra.n) + 1
		"coins_x2":
			data.coins += amount
	_changed()
	return true





func season_info() -> Dictionary:
	var t: = today()
	for s in cfg.live.seasons:
		var end: = Time.get_date_string_from_unix_time((day_no(s.start) + int(s.weeks) * 7) * 86400)
		if s.start <= t and t < end:
			var x: Dictionary = s.duplicate()
			x.end = end
			return x
	return {}



func season() -> Dictionary:
	var id: String = season_info().get("id", "")
	var s: Dictionary = data.season
	if s.id != id:
		if s.id != "":
			for c in _season_claimable(s):
				send_mail("season_left", c.reward)
		var carry: bool = s.id == "" and s.paid
		data.season = {id = id, xp = 0, paid = carry, free_got = [], paid_got = []}
	return data.season


func season_level() -> int:
	return _season_level(season())


func _season_level(s: Dictionary) -> int:
	var se: Dictionary = cfg.live.season
	return mini(int(se.levels), int(s.xp) / int(se.xp_per_level))


func season_add_xp(n: int) -> void :
	if n > 0 and season().id != "":
		data.season.xp = int(data.season.xp) + n



func season_claimable() -> Array:
	return _season_claimable(season())


func _season_claimable(s: Dictionary) -> Array:
	var out: = []
	for track in ["free", "paid"]:
		if track == "paid" and not s.paid:
			continue
		var table: Dictionary = cfg.live.season[track]
		for k in table:
			if int(k) <= _season_level(s) and not int(k) in s[track + "_got"]:
				out.append({level = int(k), paid = track == "paid", reward = table[k]})
	return out



func season_claim_all() -> Array:
	var list: = season_claimable()
	for c in list:
		_give(c.reward)
		data.season[("paid" if c.paid else "free") + "_got"].append(c.level)
	if not list.is_empty():
		_changed()
	return list



func season_buy_level() -> bool:
	var se: Dictionary = cfg.live.season
	if season().id == "" or season_level() >= int(se.levels) or not spend_dust(int(se.level_price_dust)):
		return false
	data.season.xp = (season_level() + 1) * int(se.xp_per_level)
	_changed()
	return true





func send_mail(kind: String, reward: Dictionary, days: = -1) -> Dictionary:
	data.mail_seq += 1
	var keep: = days if days > 0 else int(cfg.live.mail.keep_days)
	var m: = {id = "m%d" % data.mail_seq, kind = kind, reward = reward, at = now(), expires = now() + keep * DAY_MS, claimed = false}
	data.mail.append(m)
	_changed()
	return m



func mail() -> Array:
	refresh()
	var out: Array = data.mail.duplicate()
	out.reverse()
	return out


func mail_claim(id: String) -> bool:
	refresh()
	for m in data.mail:
		if m.id == id and not m.claimed:
			m.claimed = true
			_give(m.reward)
			_changed()
			return true
	return false



func mail_claim_all() -> int:
	var n: = 0
	for m in mail():
		if not m.claimed and mail_claim(m.id):
			n += 1
	return n





func events_active() -> Array:
	return cfg.live.events.filter( func(e): return e.get("enabled", false) and e.start <= today() and today() < e.end)


func _event_cfg(id: String) -> Dictionary:
	for e in cfg.live.events:
		if e.id == id:
			return e
	return {}



func _event_shop_end(e: Dictionary) -> String:
	return Time.get_date_string_from_unix_time((day_no(e.end) + int(e.get("shop_grace_days", 0))) * 86400)


func event_shop_open(id: String) -> bool:
	var e: = _event_cfg(id)
	return not e.is_empty() and e.get("enabled", false) and e.start <= today() and today() < _event_shop_end(e)



func event_rec(id: String) -> Dictionary:
	if not data.events.has(id):
		data.events[id] = {cur = 0, bought = {}, closed = false}
	return data.events[id]


func _event_drop(stars: int) -> Dictionary:
	var out: = {}
	for e in events_active():
		var n: = int(e.win) + int(e.per_star) * stars
		event_rec(e.id).cur = int(event_rec(e.id).cur) + n
		out[e.id] = n
	return out



func event_buy(id: String, item: String) -> bool:
	if not event_shop_open(id):
		return false
	var rec: = event_rec(id)
	for it in _event_cfg(id).shop:
		if it.id == item and int(rec.bought.get(item, 0)) < int(it.limit) and int(rec.cur) >= int(it.cost):
			rec.cur = int(rec.cur) - int(it.cost)
			rec.bought[item] = int(rec.bought.get(item, 0)) + 1
			_give(it.reward)
			_changed()
			return true
	return false



func _close_events() -> void :
	for id in data.events:
		var rec: Dictionary = data.events[id]
		var e: = _event_cfg(id)
		if rec.closed or ( not e.is_empty() and e.get("enabled", false) and today() < _event_shop_end(e)):
			continue
		rec.closed = true
		var coins: = int(rec.cur) * int(e.get("leftover_coins", 0))
		rec.cur = 0
		if coins > 0:
			send_mail("event_left", {coins = coins})





func dungeon_attr(day: = "") -> String:
	return cfg.live.dungeon.weekday_attrs[posmod(day_no(day if day != "" else today()) + 4, 7)]


func dungeon_open() -> bool:
	return is_open(cfg.live.dungeon.unlock)


func dungeon_left() -> int:
	var rec: Dictionary = data.dungeon
	return int(cfg.live.dungeon.daily) - (int(rec.n) if rec.day == today() else 0)



func dungeon_stage(level: int, attr: = "") -> String:
	var a: = dungeon_attr()
	var refs: Array = cfg.live.dungeon.stages.get(attr if a == "any" else a, [])
	return refs[level] if level >= 0 and level < refs.size() else ""



func dungeon_can_take(id: String) -> bool:
	return owned(id) and cfg.attr(id) != "" and (dungeon_attr() == "any" or cfg.attr(id) == dungeon_attr())



func _finish_dungeon(r: Dictionary, out: Dictionary) -> void :
	var friend: String = r.get("friend", "")
	if not r.won or not dungeon_open() or dungeon_left() <= 0 or not dungeon_can_take(friend):
		return
	var rec: Dictionary = data.dungeon
	data.dungeon = {day = today(), n = (int(rec.n) if rec.day == today() else 0) + 1}
	var levels: Array = cfg.live.dungeon.levels
	var lvl: Dictionary = levels[clampi(int(r.get("level", 0)), 0, levels.size() - 1)]
	data.shards[friend] = int(data.shards.get(friend, 0)) + int(lvl.shards)
	data.crayons += int(lvl.crayons)
	out.shards = {id = friend, n = int(lvl.shards)}
	out.crayons = int(lvl.crayons)
	mission_add("dungeon")






func refresh() -> void :
	season()
	weekly()
	if missions_on():
		missions()
	_close_events()
	var t: = today()
	for lm in cfg.live.mail.list:
		if lm.start <= t and t < lm.end and not lm.id in data.mail_got:
			data.mail_got.append(lm.id)
			send_mail(lm.kind, lm.reward, int(lm.get("keep_days", -1)))
	data.mail = data.mail.filter( func(m): return int(m.expires) > now())
