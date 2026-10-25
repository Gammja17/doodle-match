class_name BoardTile
extends RefCounted
## 판 위의 한 칸. type 0~ 는 낙서 친구 색, 음수는 색 없는 칸.

const ITEM := -1     # 아이템 (색 없음)
const DELIVER := -2  # 내려보내기 조각: 맨 밑까지 내리면 모임
const BLOCK := -3    # 장애물 (block, hp)

var id := 0
var type := 0
var special := &""   # Board.ERASER_H | ERASER_V | PUSHPIN | CRAYON | PAPER_PLANE
var block := &""     # Board.STICKY | INK | CRUMBS
var hp := 0
var taped := false   # 스카치테이프로 붙은 칸: 못 움직이고, 한 번 터뜨리면 테이프만 떨어짐
var deliver_kind := ""
var target := Vector2i(-1, -1)  # 종이비행기가 날아갈 곳 (효과를 셀 때 정함)


func _init(p_id: int, p_type: int, p_special: StringName = &"") -> void:
	id = p_id
	type = p_type
	special = p_special
