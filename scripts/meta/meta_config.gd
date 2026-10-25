class_name MetaConfig
extends RefCounted

















const OVERRIDES: = "overrides"

static var _shared: MetaConfig
static var _over: = {}

var economy: Dictionary
var friends: Dictionary
var route: Dictionary
var roster: Dictionary
var modes: Dictionary
var extra: Dictionary
var gacha: Dictionary
var products: Dictionary
var live: Dictionary
var rules: Dictionary

var friend_by_id: = {}
var recruit_by_id: = {}
var play_ids: = {}
var route_n: = {}
var route_ref: = {}



static func shared() -> MetaConfig:
	if _shared == null:
		_shared = MetaConfig.new()
	return _shared


func _init(dir: = "res://data") -> void :
	economy = read_data("economy", dir)
	friends = read_data("friends", dir)
	route = read_data("route", dir)
	roster = read_data("roster", dir)
	modes = read_data("modes", dir)
	extra = read_data("meta_extra", dir)
	gacha = read_data("gacha", dir)
	products = read_data("products", dir)
	live = read_data("live", dir)
	rules = read_data("rules", dir)
	for f in friends.friends:
		friend_by_id[f.id] = f
	for s in route.stages:
		route_n[s.ref] = int(s.n)
		route_ref[int(s.n)] = s.ref
	for f in roster.friends:
		play_ids[f.id] = String(f.get("web", f.id))
	for f in roster.friends:
		var r: = _recruit_of(f.get("get", {}))
		if not r.is_empty():
			r.friend = play_ids[f.id]
			recruit_by_id[r.friend] = r




func _recruit_of(g: Dictionary) -> Dictionary:
	if g.has("guest"):
		return {by = "treat", treat = g.guest.treat, count = int(g.guest.count), src = "guest"}
	match g.get("by", ""):
		"route":
			return {by = "clear", route = int(g.n), src = "route"}
		"story":
			var ch: Dictionary = route.chapters[int(g.chapter) - 1]
			return {by = "clear", route = int(ch.first) + int(ch.count) - 1, src = "story", chapter = int(g.chapter)}
		"after":
			return {by = "after", friend_after = play_ids.get(g.friend, g.friend), clears = int(g.clears), src = "after"}
		"treat":
			return {by = "treat", treat = g.treat, count = int(g.count), src = "treat"}
	return {}



static func read_data(name: String, dir: = "res://data") -> Dictionary:
	var d: = _read(dir, name)
	if name != OVERRIDES:
		if not _over.has(dir):
			_over[dir] = _read(dir, OVERRIDES) if FileAccess.file_exists("%s/%s.json" % [dir, OVERRIDES]) else {}
		var o: Dictionary = _over[dir].get(name, {})
		if not o.is_empty():
			merge(d, o.duplicate(true))
	return d



static func merge(base: Dictionary, over: Dictionary) -> void :
	for k in over:
		var a = base.get(k)
		var b = over[k]
		if a is Dictionary and b is Dictionary:
			merge(a, b)
		elif a is Array and b is Array and _by_id(a) and _by_id(b):
			for item in b:
				var i: int = a.find_custom( func(x): return x.id == item.id)
				if i >= 0:
					merge(a[i], item)
				else:
					a.append(item)
		else:
			base[k] = b


static func _by_id(a: Array) -> bool:
	return not a.is_empty() and a.all( func(x): return x is Dictionary and x.has("id"))


static func _read(dir: String, name: String) -> Dictionary:
	var text: = FileAccess.get_file_as_string("%s/%s.json" % [dir, name])
	var d = JSON.parse_string(text)
	assert (d is Dictionary, "%s.json을 못 읽음" % name)
	return d



func play_id(id: String) -> String:
	return play_ids.get(id, id)



func is_treat_friend(id: String) -> bool:
	return recruit_by_id.get(id, {}).get("by") == "treat"



func tier(id: String) -> int:
	return int(gacha.tiers.get(id, 0))



func attr(id: String) -> String:
	return String(friend_by_id.get(id, {}).get("attr", gacha.attrs.get(id, "")))


func outfit(id: String) -> Dictionary:
	for o in extra.outfits:
		if o.id == id:
			return o
	return {}
