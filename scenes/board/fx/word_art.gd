class_name WordArt
extends RefCounted



const DIR: = "res://art/words/"


const DIGIT: = "res://art/words/digits/%s.png"
const DIGIT_GOLD: = "res://art/words/digits_gold/%s.png"
const SKILL: = "res://art/words/skills/%s_s%s.png"

const KEYS: = {
	"시작!": "start", "보너스 타임!": "bonus_time", "섞는 중…": "shuffle", "이동 끝…": "out_of_moves", "후퇴…": "retreat", 
	"다 지웠다!": "clear_puzzle", "토벌 성공!": "clear_battle", "피버 타임!": "fever", "아쉬워…": "fail", "콤보": "combo", 
	"좋아!": "praise_1", "멋져!": "praise_2", "대단해!": "praise_3", "굉장해!": "praise_4", "최고!": "praise_5", 
}

const GLYPHS: = {"+": "plus", "-": "minus", "−": "minus", "×": "x", "!": "bang"}

static var _cache: = {}


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]



static func of(text: String) -> Texture2D:
	return _load(DIR + KEYS[text] + ".png") if KEYS.has(text) else null



static func glyph(ch: String, gold: = false) -> Texture2D:
	var name: String = ch if ch.is_valid_int() else GLYPHS.get(ch, "")
	return _load((DIGIT_GOLD if gold else DIGIT) % name) if name != "" else null



static func glyphs(text: String, gold: = false) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for ch in text:
		var t: = glyph(ch, gold)
		if t == null:
			return []
		out.append(t)
	return out



static func skill(rid: String, n: String) -> Texture2D:
	return _load(SKILL % [rid, n])
