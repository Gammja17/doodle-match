class_name StoryDB
extends RefCounted



const DIR: = "res://data/story/"
const CAST_FILE: = "cast.json"
const BG_FILE: = "backgrounds.json"
const BONDS_DIR: = "bonds/"
const LV_MAX: = 10
const ROUTE_FILE: = "res://data/route.json"


const SIDES: = ["left", "right", "left2", "right2"]
const FACES: = ["normal", "happy", "angry", "sad", "surprised", "scared", "tired", "shy", "think"]

const COMMANDS: = {
	say = ["text", "face", "name"], 
	narr = [], 
	enter = ["at", "face"], 
	exit = [], 
	emote = ["face"], 
	shake = [], 
	hop = [], 
	wait = [], 
	title = ["sub"], 
	join = [], 
	bg = [], 
}

const WAITS_TAP: = ["say", "narr", "title"]
const SCREEN: = "screen"
const MAX_TEXT: = 80

static var _cast: = {}
static var _scenes: = {}
static var _loaded: = false
static var _chapter_of: = {}


static func cast() -> Dictionary:
	_load()
	return _cast


static func scene(trigger: String) -> Dictionary:
	_load()
	return _scenes.get(trigger, {})


static func triggers() -> Array:
	_load()
	return _scenes.keys()



static func bonds(friend: String) -> Array:
	_load()
	var out: = []
	for t in _scenes:
		if t.begins_with("bond:%s:" % friend):
			var s: Dictionary = _scenes[t]
			out.append({trigger = t, title = s.get("title", ""), level = int(s.get("level", 1))})
	out.sort_custom( func(a, b): return a.level < b.level)
	return out



static func reload() -> void :
	_loaded = false
	_load()



static func command_of(step: Dictionary) -> String:
	for k in step:
		if COMMANDS.has(k):
			return k
	return ""




static func default_bg(trigger: String) -> String:
	var ch: = chapter_of(trigger)
	return _read(DIR + BG_FILE).get("chapters", {}).get(ch, ch)



static func bg_path(id: String) -> String:
	return str(_read(DIR + BG_FILE).get("dir", "res://art/story/bg/")) + id + ".png"


static func chapter_of(trigger: String) -> String:
	if trigger == "prologue":
		return "prologue"
	var parts: = trigger.split(":")
	if parts.size() != 2 or parts[0] not in ["before", "after"]:
		return ""
	if _chapter_of.is_empty():
		for s in _read(ROUTE_FILE).get("stages", []):
			_chapter_of[s.ref] = s.chapter
	return _chapter_of.get(parts[1], "")


static func _load() -> void :
	if _loaded:
		return
	_loaded = true
	_cast = _read(DIR + CAST_FILE).get("cast", {})
	_scenes = {}
	for f in _story_files():
		for s in _read(DIR + f).get("scenes", []):
			if s is Dictionary and s.has("trigger"):
				_scenes[s.trigger] = s.merged({file = f})



static func _story_files() -> PackedStringArray:
	var out: = PackedStringArray()
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json") and f not in [CAST_FILE, BG_FILE]:
			out.append(f)
	for f in DirAccess.get_files_at(DIR + BONDS_DIR):
		if f.ends_with(".json"):
			out.append(BONDS_DIR + f)
	out.sort()
	return out


static func _read(path: String) -> Dictionary:
	var txt: = FileAccess.get_file_as_string(path)
	var v: Variant = JSON.parse_string(txt)
	return v if v is Dictionary else {}





static func check() -> PackedStringArray:
	var errs: = PackedStringArray()
	var cast_data: = _read(DIR + CAST_FILE)
	if not cast_data.get("cast") is Dictionary:
		errs.append("%s: cast 표가 없음" % CAST_FILE)
		return errs
	var c: Dictionary = cast_data.cast
	for id in c:
		var info: Dictionary = c[id]
		if str(info.get("name", "")).is_empty():
			errs.append("%s: %s 이름 없음" % [CAST_FILE, id])
		var st: String = info.get("sticker", "")
		if not st.is_empty() and not FileAccess.file_exists(st):
			errs.append("%s: %s 스티커 파일 없음 %s" % [CAST_FILE, id, st])
		var faces: Dictionary = info.get("faces", {})
		for f in faces:
			if f not in FACES:
				errs.append("%s: %s 모르는 표정 %s" % [CAST_FILE, id, f])
			elif not FileAccess.file_exists(faces[f]):
				errs.append("%s: %s %s 표정 그림 없음 %s" % [CAST_FILE, id, f, faces[f]])
	var refs: = {}
	for s in _read(ROUTE_FILE).get("stages", []):
		refs[s.ref] = true
	var seen: = {}
	for f in _story_files():
		var txt: = FileAccess.get_file_as_string(DIR + f)
		var data: Variant = JSON.parse_string(txt)
		if not data is Dictionary or not data.get("scenes") is Array:
			errs.append("%s: JSON이 아니거나 scenes 배열이 없음" % f)
			continue
		for s in data.scenes:
			var where: = "%s %s" % [f, s.get("trigger", "?")]
			var t: String = s.get("trigger", "")
			if not _trigger_ok(t, refs):
				errs.append("%s: 트리거가 틀림 (prologue, before:<판 ref>, after:<판 ref>, bond:<id>:<번호>)" % where)
			if seen.has(t):
				errs.append("%s: 트리거가 %s에도 있음" % [where, seen[t]])
			seen[t] = f
			var bond: = t.begins_with("bond:")
			for k in s:
				if k not in ["trigger", "note", "steps"] and not (bond and k in ["title", "level"]):
					errs.append("%s: 모르는 키 %s" % [where, k])
			if bond:
				errs.append_array(_check_bond(s, f, c, where))
			if not s.get("steps") is Array or s.steps.is_empty():
				errs.append("%s: steps가 비었음" % where)
				continue
			errs.append_array(_check_steps(s.steps, c, where))
	return errs


static func _trigger_ok(t: String, refs: Dictionary) -> bool:
	if t == "prologue":
		return true
	var parts: = t.split(":")
	if parts.size() == 3 and parts[0] == "bond":
		return not parts[1].is_empty() and parts[2].is_valid_int()
	return parts.size() == 2 and parts[0] in ["before", "after"] and refs.has(parts[1])



static func _check_bond(s: Dictionary, file: String, c: Dictionary, where: String) -> PackedStringArray:
	var errs: = PackedStringArray()
	var friend: String = s.trigger.split(":")[1]
	if not c.has(friend):
		errs.append("%s: 모르는 캐릭터 %s" % [where, friend])
	if file != BONDS_DIR + friend + ".json":
		errs.append("%s: %s 이야기는 %s%s.json에 둬야 함" % [where, friend, BONDS_DIR, friend])
	if not s.get("title") is String or s.title.is_empty():
		errs.append("%s: 친구 이야기 제목(title)이 없음" % where)
	var lv: Variant = s.get("level")
	if not (lv is float or lv is int) or lv < 1 or lv > LV_MAX:
		errs.append("%s: level은 1~%d" % [where, LV_MAX])
	return errs



static func _check_steps(steps: Array, c: Dictionary, where: String) -> PackedStringArray:
	var errs: = PackedStringArray()
	var on: = {}
	var taps: = 0
	for i in steps.size():
		var st: Variant = steps[i]
		var at: = "%s #%d" % [where, i + 1]
		if not st is Dictionary:
			errs.append("%s: 스텝이 사전이 아님" % at)
			continue
		var cmd: = command_of(st)
		if cmd.is_empty():
			errs.append("%s: 모르는 명령 %s" % [at, st.keys()])
			continue
		for k in st:
			if k != cmd and k not in COMMANDS[cmd]:
				errs.append("%s: %s에 모르는 키 %s" % [at, cmd, k])
		if cmd in WAITS_TAP:
			taps += 1
		var who: Variant = st[cmd]
		if st.has("face") and st.face not in FACES:
			errs.append("%s: 모르는 표정 %s" % [at, st.face])
		match cmd:
			"say":
				if not c.has(who):
					errs.append("%s: 모르는 캐릭터 %s" % [at, who])
				errs.append_array(_check_text(st.get("text"), at))
			"narr":
				errs.append_array(_check_text(who, at))
			"title":
				if not who is String or who.is_empty():
					errs.append("%s: title 글이 없음" % at)
			"wait":
				if not (who is float or who is int) or who <= 0 or who > 3:
					errs.append("%s: wait는 0~3초" % at)
			"enter":
				if not c.has(who):
					errs.append("%s: 모르는 캐릭터 %s" % [at, who])
				elif on.has(who):
					errs.append("%s: %s 이미 나와 있음" % [at, who])
				var side: String = st.get("at", "")
				if side not in SIDES:
					errs.append("%s: at은 %s" % [at, SIDES])
				elif side in on.values():
					errs.append("%s: %s 자리에 이미 누가 있음" % [at, side])
				else:
					on[who] = side
			"bg":

				if not who is String or not RegEx.create_from_string("^[a-z0-9_]+$").search(who):
					errs.append("%s: bg는 영문 소문자·숫자·_ 이름 (%s)" % [at, who])
			"join":

				if not c.has(who):
					errs.append("%s: 모르는 캐릭터 %s" % [at, who])
			"exit", "emote", "hop", "shake":
				if cmd == "shake" and who == SCREEN:
					pass
				elif not on.has(who):
					errs.append("%s: %s가 무대에 없는데 %s" % [at, who, cmd])
				elif cmd == "exit":
					on.erase(who)
				if cmd == "emote" and not st.has("face"):
					errs.append("%s: emote에 face가 없음" % at)
	if taps == 0:
		errs.append("%s: 탭으로 넘길 대사가 하나도 없음" % where)
	return errs


static func _check_text(t: Variant, at: String) -> PackedStringArray:
	if not t is String or t.strip_edges().is_empty():
		return PackedStringArray(["%s: 대사가 비었음" % at])
	if t.length() > MAX_TEXT:
		return PackedStringArray(["%s: 대사가 %d자 (최대 %d)" % [at, t.length(), MAX_TEXT]])
	return PackedStringArray()
