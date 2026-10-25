class_name GuildConfig
extends RefCounted







const ART: = "res://ui/art/guild/furniture/%s_1.png"

var house: Dictionary
var rules: Dictionary
var rooms: Array
var room_by_id: = {}
var furn: = {}
var furn_order: = []
var walls: = {}
var floors: = {}
var groups: Dictionary
var friends: = {}
var pairs: = []
var cast_of: = {}


func _init(dir: = "res://data/guild", economy: Dictionary = {}) -> void :
	if economy.is_empty():
		economy = MetaConfig.shared().economy
	house = economy.house
	rules = _read(dir, "guild")
	rooms = _read(dir, "rooms").rooms
	for r in rooms:
		room_by_id[r.id] = r
	var f: = _read(dir, "furniture")
	for e in house.furniture:
		var kind: = "wall" if e.get("wall", false) else "flat" if e.get("flat", false) else "floor"
		_add_furn(e.id, f.furniture[e.id], int(e.price), kind)
	for id in f.theme:
		var t: Dictionary = f.theme[id]
		_add_furn(id, t, int(t.price), t.kind)
	for e in house.walls:
		walls[e.id] = {id = e.id, name = f.walls[e.id].name, price = int(e.price), color = f.walls[e.id].color}
	for e in house.floors:
		floors[e.id] = {id = e.id, name = f.floors[e.id].name, price = int(e.price), color = f.floors[e.id].color}

	var res: = _read(dir, "residents")
	groups = res.groups
	var play_of: = {}
	for r in MetaConfig.read_data("roster").friends:
		var play: = String(r.get("web", r.id))
		play_of[r.id] = play
		cast_of[play] = r.id
		if res.friends.has(r.id):
			var e: Dictionary = res.friends[r.id].duplicate()
			e.group = r.get("group", "") if r.get("group") != null else ""
			friends[play] = e
	for p in res.pairs:
		var a: String = play_of.get(p.a, p.a)
		var b: String = play_of.get(p.b, p.b)
		if friends.has(a) and friends.has(b):
			pairs.append({a = a, b = b, talk = p.talk.map( func(t): return [play_of.get(t[0], t[0]), t[1]])})


func _add_furn(id: String, src: Dictionary, price: int, kind: String) -> void :
	var d: = src.duplicate()
	d.id = id
	d.price = price
	d.kind = kind
	for k in ["x", "y", "w", "h"]:
		d[k] = int(d[k])
	if not d.has("art") and FileAccess.file_exists(ART % id):
		d.art = ART % id
	furn[id] = d
	furn_order.append(id)


static func _read(dir: String, name: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [dir, name]))
	assert (d is Dictionary, "guild/%s.json을 못 읽음" % name)
	return d


func friend_name(id: String) -> String:
	return friends.get(id, {}).get("name", id)



func text(key: String, fallback: String) -> String:
	var t: = tr(key)
	return fallback if t == key else t



func friend_lines(id: String, kind: String) -> Array:
	var f: Dictionary = friends.get(id, {})
	var base: = "char.%s.guild." % cast_of.get(id, id)
	if kind == "gift":
		return [text(base + "gift", f.get("gift", ""))]
	var src: Array = f.get("lines" if kind == "tap" else kind, [])
	var out: = []
	for k in src.size():
		out.append(text(base + kind + str(k + 1), src[k]))
	return out



func pair_talk(p: Dictionary) -> Array:
	var base: = "guild.pair.%s.%s." % [cast_of.get(p.a, p.a), cast_of.get(p.b, p.b)]
	var out: = []
	for k in p.talk.size():
		out.append([p.talk[k][0], text(base + str(k + 1), p.talk[k][1])])
	return out
