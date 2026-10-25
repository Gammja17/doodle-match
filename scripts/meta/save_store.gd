class_name SaveStore
extends RefCounted








const VERSION: = 3
const FORMAT: = 2
const PATH: = "user://save.json"
const SALT: = "doodle-match/save/1"



static func fresh(cfg: MetaConfig) -> Dictionary:
	var own: = {}
	for id in cfg.friends.starters:
		own[id] = 1
	return {
		version = VERSION, 
		saved_at = 0, 
		coins = int(cfg.economy.start_coins), 
		tickets = 0, 
		own = own, 
		shards = {}, 
		treats = {}, 
		join_at = {}, 
		wish = "", 
		outfits = {}, 
		wearing = {}, 
		stars = {}, 
		hearts = int(cfg.economy.hearts.max), 
		heart_at = 0, 
		unlimited_until = 0, 
		items = {}, 
		train = {hp = 0, atk = 0}, 
		aff = {}, 
		pat = {}, 
		att = {n = 0, day = "", cycles = 0}, 
		mis = {}, 
		dch = {day = "", done = false}, 
		vault = {day = "", n = 0}, 
		snack_vault = {day = "", n = 0}, 
		snack_pick = String(cfg.economy.stage_treat.rotation[0]), 

		started_at = 0, 
		dust = {paid = 0, free = 0}, 
		sparkle_tickets = 0, 
		stamps = 0, 
		first10_used = false, 
		wild = {"1": 0, "2": 0, "3": 0}, 
		crayons = 0, 
		overpaint = {}, 
		pick = {"2": 0, "3": 0}, 
		purchases = {}, 
		bought = {}, 
		monthly = {until = "", last = ""}, 
		growth = {bought = false, got = []}, 
		no_ads = false, 
		ads = {day = "", n = {}}, 
		vault_extra = {day = "", n = 0}, 
		gacha_log = [], 

		weekly = {week = -1, got = {}, done = {}, bonus = false}, 
		season = {id = "", xp = 0, paid = false, free_got = [], paid_got = []}, 
		mail = [], 
		mail_seq = 0, 
		mail_got = [], 
		events = {}, 
		dungeon = {day = "", n = 0}, 

		buff = "", 
		free_bowl = 0, 
		bowls = 0, 

		party = [], 
		app = {story = {}, tips = {}, playing = ""}, 

		device_id = "", 
		tampered = false, 
		sync = {account = "", at = 0, hash = "", cloud = ""}, 
	}



static func load_ex(cfg: MetaConfig, path: = PATH) -> Dictionary:
	var skipped: = []
	for p in [path, path + ".bak1", path + ".bak2", path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var r: = read_file(p)
		if not r.ok:
			push_warning("저장 파일이 깨져서 건너뜀: " + p)
			skipped.append(p)
			continue
		var v: = int(r.data.get("version", 0))
		if v < VERSION and p == path and not FileAccess.file_exists("%s.v%d" % [path, v]):
			DirAccess.copy_absolute(path, "%s.v%d" % [path, v])
		var d: = upgrade(cfg, r.data)
		if r.tampered:
			d.tampered = true
		return {data = d, source = p, tampered = r.tampered, too_new = v > VERSION, from_version = v, skipped = skipped}
	return {data = fresh(cfg), source = "fresh", tampered = false, too_new = false, from_version = VERSION, skipped = skipped}


static func load_from(cfg: MetaConfig, path: = PATH) -> Dictionary:
	return load_ex(cfg, path).data



static func read_file(p: String) -> Dictionary:
	return decode(FileAccess.get_file_as_string(p))



static func decode(text: String) -> Dictionary:
	var cut: = text.find("\n")
	var j: = JSON.new()
	if cut > 0 and j.parse(text.left(cut)) == OK and j.data is Dictionary and j.data.has("hash"):
		var head: Dictionary = j.data
		var body: = text.substr(cut + 1).strip_edges()
		if j.parse(body) != OK or not j.data is Dictionary:
			return {ok = false}
		return {ok = true, data = _ints(j.data), tampered = digest(body) != head.hash}
	if j.parse(text) == OK and j.data is Dictionary:
		return {ok = true, data = _ints(j.data), tampered = false}
	return {ok = false}


static func save_to(d: Dictionary, path: = PATH) -> bool:
	var tmp: = path + ".tmp"
	var text: = encode(d)
	var f: = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		return false
	if FileAccess.file_exists(path):
		if read_file(path).ok:
			DirAccess.remove_absolute(path + ".bak2")
			if FileAccess.file_exists(path + ".bak1"):
				DirAccess.rename_absolute(path + ".bak1", path + ".bak2")
			DirAccess.rename_absolute(path, path + ".bak1")
		else:
			DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK



static func encode(d: Dictionary) -> String:
	var body: = JSON.stringify(d)
	return JSON.stringify({format = FORMAT, version = int(d.get("version", VERSION)), hash = digest(body)}) + "\n" + body + "\n"


static func digest(body: String) -> String:
	var h: = HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update((SALT + body).to_utf8_buffer())
	return h.finish().hex_encode()



static func content_hash(d: Dictionary) -> String:
	var x: = d.duplicate(true)
	for k in ["saved_at", "sync"]:
		x.erase(k)
	return digest(JSON.stringify(x, "", true))




static func upgrade(cfg: MetaConfig, d: Dictionary) -> Dictionary:
	var v: = int(d.get("version", 0))
	if v < 1:
		d = _from_v0(d)
	if v < 2:
		d = _from_v1(d)
	if v < 3:
		d = _from_v2(d, cfg)
	var base: = fresh(cfg)
	for k in base:
		if not d.has(k):
			d[k] = base[k]
	d.version = maxi(v, VERSION)
	return d



static func _from_v0(d: Dictionary) -> Dictionary:
	return d



static func _from_v1(d: Dictionary) -> Dictionary:
	return d




static func _from_v2(d: Dictionary, cfg: MetaConfig) -> Dictionary:
	if d.has("own"):
		for id in cfg.friends.starters:
			if int(d.own.get(id, 0)) < 1:
				d.own[id] = 1
	return d



static func _ints(v: Variant) -> Variant:
	if v is float and v == floorf(v):
		return int(v)
	if v is Dictionary:
		for k in v:
			v[k] = _ints(v[k])
	elif v is Array:
		for i in v.size():
			v[i] = _ints(v[i])
	return v
