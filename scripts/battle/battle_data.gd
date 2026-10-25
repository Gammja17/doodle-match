class_name BattleData
extends RefCounted



static var _cache: = {}


static func _json(name: String) -> Dictionary:
	if not _cache.has(name):
		_cache[name] = MetaConfig.read_data(name)
	return _cache[name]


static func rules() -> Dictionary:
	return _json("rules").battle



static func fever_turns() -> int:
	return int(_json("rules").puzzle.fever_turns)


static func friends() -> Dictionary:
	return _json("friends")


static func friend(id: String) -> Dictionary:
	for f in friends().friends:
		if f.id == id:
			return f
	push_error("친구 %s가 friends.json에 없음" % id)
	return {}


static func enemy_skill(enemy: String) -> String:
	for k in _json("enemies").kinds:
		if k.id == enemy:
			return k.skill if k.skill != null else ""
	return ""


static func enemy_skills() -> Dictionary:
	return _json("enemies").skills


static func battle(id: String) -> Dictionary:
	for b in _json("battles").battles:
		if b.id == id:
			return b
	push_error("토벌 %s가 battles.json에 없음" % id)
	return {}



static func route_n(ref: String) -> int:
	for s in _json("route").stages:
		if s.ref == ref:
			return int(s.n)
	return 0



static func level_mult(id: String, lv: float) -> float:
	var up: Dictionary = _json("economy").upgrade
	var treat: = false
	for r in _json("economy").recruit:
		if r.friend == id and r.by == "treat":
			treat = true
	var per: float = up.power_per_lv_treat_friend if treat else up.power_per_lv
	return 1.0 + per * maxf(0.0, lv - 1.0)



static func attr_mult(atk: String, def: String) -> float:
	var r: = rules()
	if (atk == "light" and def == "dark") or (atk == "dark" and def == "light"):
		return r.light_dark_mult
	var beats: Dictionary = friends().beats
	if beats.get(atk, "") == def:
		return r.attr_win
	if beats.get(def, "") == atk:
		return r.attr_lose
	return 1.0
