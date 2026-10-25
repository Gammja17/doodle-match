class_name GoalChip
extends HBoxContainer
## 목표 하나: 아이콘 + 남은 수 (다 채우면 체크)

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count


func set_goal(icon: Texture2D, left: int, prefix := "") -> void:
	_icon.texture = icon
	_icon.visible = icon != null
	_count.text = "완료" if left == 0 else prefix + str(left)  # ✓는 웹 글꼴에 없어서 글자로


## 아이콘 가운데의 화면 좌표 (날아오는 그림이 여기로)
func center() -> Vector2:
	return _icon.get_global_rect().get_center() if _icon.visible else get_global_rect().get_center()


## 맞으면 통 (웹 chipBump: 1.28, 220ms)
func bump() -> void:
	pivot_offset = size / 2
	Juice.play(self, position, [{s = 1.0}, {s = 1.28, b = 1.3}, {s = 1.0}], 220.0, "ease-out")
