class_name BattleArt
extends Resource
## 토벌 그림 매핑 한 곳: 적(id별, 없으면 등급 그림), 친구 얼굴·컷인(friends.json id별), 속성 아이콘.
## 그림을 갈아 끼울 때는 battle_art.tres만 바꾸면 됨

@export var pencil: Texture2D     # 연필 휘갈김
@export var ballpoint: Texture2D  # 볼펜 낙서
@export var marker: Texture2D     # 매직 먹칠 (보스)
@export var enemies: Dictionary = {}       # "e01" -> Texture2D
@export var friend_faces: Dictionary = {}  # "f01" -> Texture2D (판 구슬·파티 자리)
## 얼굴 그림이 아직 없는 친구가 차례로 빌려 쓰는 임시 얼굴 (다른 친구로 오해 안 하게 웹 id가 없는 캐릭터들)
@export var stand_in_faces: Array[Texture2D] = []
@export var cutins: Dictionary = {}        # "f01" -> Texture2D (스킬 컷인). 없으면 얼굴로
@export var attr_icons: Dictionary = {}    # "brave" -> Texture2D


func enemy_texture(w: Dictionary) -> Texture2D:
	if enemies.has(w.enemy) and not w.get("boss", false):
		return enemies[w.enemy]
	match w.get("tier", "pencil"):
		"ballpoint": return ballpoint
		"marker": return marker
	return pencil


## 편성 순서대로 얼굴: 친구 얼굴 아이콘(FriendLook) → friend_faces → 임시 얼굴을 차례로
func team_faces(ids: Array) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var look := FriendLook.shared()
	var k := 0
	for id in ids:
		if look.has_face(id):
			out.append(look.face(id))
		elif friend_faces.has(id):
			out.append(friend_faces[id])
		else:
			out.append(stand_in_faces[k % stand_in_faces.size()])
			k += 1
	return out


## 임시 글자 (이름·대사 없이 속성·역할만). 속성 이름은 docs/design/roster.md
const ATTR_NAME := {"brave": "불꽃", "odd": "새싹", "cry": "물결", "light": "햇살", "dark": "달그림자"}
const ATTR_COLOR := {"brave": Color("e2543f"), "odd": Color("3fa65a"), "cry": Color("3f7fe0"), "light": Color("d9a400"), "dark": Color("7a4fc0")}
const ROLE_NAME := {"sleep": "재우기", "poison": "독", "weak": "어둠", "drain": "게이지 뺏기", "ink_spit": "잉크 뱉기", "stomp": "쿵쿵", "heal": "회복"}
