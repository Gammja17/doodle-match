class_name FriendLook
extends Resource
## 친구 id -> 화면에 보이는 이름·직업·등급·얼굴·스티커·카드 일러·스킬 컷인. 매핑은 scenes/app/friend_look.tres 한 곳.
## id가 두 가지라서 하나로 이어 봄 (데이터 통합은 데이터 세션 일, docs/app-notes.md):
##   로스터 id (data/story/cast.json·data/gacha.json: grenn, yuja …) — 반짝 뽑기·이야기
##   f01~f12 (data/friends.json) — 퍼즐·토벌 숫자, 코인 캡슐. data/roster.json friends[].web으로 로스터 id에 붙임
## 이름 = cast.json, 속성·역할·web = data/roster.json, 직업 = roster.md 표(jobs), 등급 = gacha.json tiers.
## 그림: 얼굴 art/tiles/<그림 id>(_prov)_circle.png, 스티커·카드·컷인 scenes/app/temp_art/chars/<그림 id>_… (scripts/app/tools/pick_art.gd가 줄여 둠).
##   그림 id = 스토리·그림 쪽 철자 (CAST_ALIAS: liv→riv …), 그림 세션 임시 확정본은 파일 이름에 _prov
## 그림이 없는 자리는 blank_face + 이름 첫 글자.
## 속성 표시 이름은 roster.md 제안(불꽃·새싹·물결·햇살·달그림자) — id·상성은 data 그대로.

const PATH := "res://scenes/app/friend_look.tres"
const CAST := "res://data/story/cast.json"
const ROSTER := "res://data/roster.json"
## 그림 경로 (웹 빌드가 이 글자를 보고 그림을 넣음 — 경로를 이어 붙이지 말고 이 모양 그대로)
const FACE_ICON := "res://art/tiles/%s_icon.png"  # 정면 낙서 얼굴 + 상징색 테두리. 있으면 이걸 먼저 씀
const FACE := "res://art/tiles/%s_circle.png"
const FACE_PROV := "res://art/tiles/%s_prov_circle.png"
const STICKER := "res://scenes/app/temp_art/chars/%s_sticker.png"
const CARD := "res://scenes/app/temp_art/chars/%s_card.jpg"
const CUTIN := "res://scenes/app/temp_art/chars/%s_cutin.webp"
const ATTR_NAME := {"brave": "불꽃", "odd": "새싹", "cry": "물결", "light": "햇살", "dark": "달그림자"}
const ATTR_COLOR := {"brave": Color("e2543f"), "odd": Color("3fa65a"), "cry": Color("3f7fe0"), "light": Color("d9a400"), "dark": Color("7a4fc0")}
## 로스터·메타 id와 스토리 cast.json·그림 파일 id 철자가 다른 친구 (데이터 세션에 맞춰 달라고 요청함, docs/app-notes.md)
const CAST_ALIAS := {"liv": "riv", "mikku": "mikkeu", "nubjuk": "neopjuk"}
const TIER_NAME := {1: "종이 스티커", 2: "반짝이 스티커", 3: "홀로그램 스티커"}

@export var jobs: Dictionary = {}     # 로스터 id -> "비버 · 전투 공병"
@export var blank_face: Texture2D
@export var colors: Dictionary = {}   # 로스터 id -> 상징색 (얼굴 테두리·터질 때 색·스킬 게이지)

static var _shared: FriendLook
var web_map := {}   # "f01" -> "ttukttak"
var _cast := {}
var _roster := {}   # 로스터 id -> roster.json 친구


static func shared() -> FriendLook:
	if _shared == null:
		_shared = load(PATH)
		_shared._cast = JSON.parse_string(FileAccess.get_file_as_string(CAST)).cast
		for f in JSON.parse_string(FileAccess.get_file_as_string(ROSTER)).friends:
			_shared._roster[f.id] = f
			if f.has("web"):
				_shared.web_map[f.web] = f.id
	return _shared


## 로스터 id (f01… 이면 이어 붙인 로스터 id, 모르는 id는 그대로)
func rid(id: String) -> String:
	return web_map.get(id, id)


func name_of(id: String) -> String:
	return _cast.get(art_id(id), {}).get("name", id)


func job(id: String) -> String:
	return jobs.get(rid(id), "")


## 속성 id: friends.json에 있으면 그 값(지금 퍼즐·토벌 숫자 기준), 없으면 roster.json
func attr(id: String) -> String:
	var f: Dictionary = MetaConfig.shared().friend_by_id.get(id, {})
	return f.get("attr", _roster.get(rid(id), {}).get("attr", ""))


## 등급 1~3 (등급이 없으면 0)
func tier(id: String) -> int:
	return MetaConfig.shared().tier(rid(id))


## 그림 파일 id (스토리·그림 쪽 철자)
func art_id(id: String) -> String:
	var r := rid(id)
	return CAST_ALIAS.get(r, r)


func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


## 얼굴 타일: 아이콘 <id>_icon.png, 없으면 확정본 <id>_circle.png, 없으면 임시 확정본 <id>_prov_circle.png
func _face_path(id: String) -> String:
	for p in [FACE_ICON % art_id(id), FACE % art_id(id), FACE_PROV % art_id(id)]:
		if ResourceLoader.exists(p):
			return p
	return ""


func has_face(id: String) -> bool:
	return _face_path(id) != ""


func face(id: String) -> Texture2D:
	var p := _face_path(id)
	return load(p) if p != "" else blank_face


## 상징색 (없으면 회색)
func color(id: String) -> Color:
	return colors.get(rid(id), Color("c9bfb2"))


func sticker(id: String) -> Texture2D:
	return _tex(STICKER % art_id(id))


func card(id: String) -> Texture2D:
	return _tex(CARD % art_id(id))


func cutin(id: String) -> Texture2D:
	return _tex(CUTIN % art_id(id))


static func attr_name(attr: String) -> String:
	return ATTR_NAME.get(attr, attr)


static func attr_color(attr: String) -> Color:
	return ATTR_COLOR.get(attr, Color.GRAY)


static func attr_icon(attr: String) -> Texture2D:
	var p := "res://ui/screens/art/attr_%s.png" % attr
	return load(p) if ResourceLoader.exists(p) else null
