class_name ShopCard
extends Button
## 꾸미기 가게 한 칸: 그림(없으면 색 견본) + 이름 + 값 또는 "보관 n" / "쓰는 중"

signal picked(id: String)

var id := ""

@onready var _swatch: Panel = $Box/Swatch
@onready var _icon: TextureRect = $Box/Swatch/Icon
@onready var _name: Label = $Box/Name
@onready var _price: Label = $Box/Price


func _ready() -> void:
	pressed.connect(func(): picked.emit(id), CONNECT_DEFERRED)  # 가게를 다시 채우면 이 칸이 지워지므로 신호가 끝난 뒤에


## icon이 있으면 견본 위에 그림 (견본은 옅은 종이색으로)
func setup(p_id: String, title: String, color: String, price_text: String, on: bool, icon: Texture2D = null) -> void:
	id = p_id
	_name.text = title
	_price.text = price_text
	_icon.texture = icon
	_icon.visible = icon != null
	var sb: StyleBoxFlat = _swatch.get_theme_stylebox("panel").duplicate()
	sb.bg_color = Color("#f3eee0") if icon else Color(color)
	_swatch.add_theme_stylebox_override("panel", sb)
	toggle_mode = true
	set_pressed_no_signal(on)
