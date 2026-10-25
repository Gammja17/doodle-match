class_name CellView
extends Control
## 판 칸 바닥 한 칸. 형광펜이 칠해지면 덧칠이 보임.

@onready var _floor: TextureRect = $Floor
@onready var _highlight: TextureRect = $Highlight


func setup(art: TileArt) -> void:
	_floor.texture = art.cell
	_highlight.texture = art.highlight


func set_painted(on: bool) -> void:
	_highlight.visible = on


## 칠해질 때 통 (웹 시럽: .3 밝게 → 1.18 → 1, 360ms)
func splash() -> void:
	_highlight.pivot_offset = size / 2
	Juice.play(_highlight, Vector2.ZERO, [{s = 0.3, b = 1.6}, {t = 0.6, s = 1.18}, {b = 1.0}], 360.0, "ease-out")
