class_name Resident
extends Control
## 방에 놓인 친구 한 명 (임시 도형: 소속 색 + 이름 첫 글자). 꾸미기 중이 아닐 때 톡 하면 tapped, 끌면 dropped.
## 자리는 발밑(아래쪽 가운데) 기준 px. 말풍선은 say(), 돌아다니기는 walk_to() (RoomView 생활 연출).

signal tapped(id: String)
signal dropped(id: String, foot: Vector2)

const DRAG_START := 8.0
const BUBBLE_TIME := 1.8
## 임시 도형 색 (그림이 오면 안 씀)
const GROUP_COLOR := {
	corner = Color("#7f93c8"), honey = Color("#e8b84a"), library = Color("#9a86c8"),
	temple = Color("#d9805a"), harbor = Color("#5ab8b0"),
}

var id := ""
var clamp_foot: Callable  # (Vector2) -> Vector2
var _press := false
var _moved := false
var _grab := Vector2.ZERO
var _bubble_tw: Tween
var _walk_tw: Tween
var _hop_tw: Tween

@onready var _body: Panel = $Body
@onready var _face: Label = $Body/Face
@onready var _name: Label = $Name
@onready var _leader: Label = $Leader
@onready var _bubble: PanelContainer = $Bubble
@onready var _text: Label = $Bubble/Text


func setup(p_id: String, info: Dictionary, is_leader: bool, draggable: bool) -> void:
	id = p_id
	_name.text = info.get("name", p_id)
	_face.text = _name.text.left(1)
	var sb: StyleBoxFlat = _body.get_theme_stylebox("panel").duplicate()
	sb.bg_color = GROUP_COLOR.get(info.get("group", ""), Color("#bbbbbb"))
	_body.add_theme_stylebox_override("panel", sb)
	_leader.visible = is_leader
	mouse_filter = Control.MOUSE_FILTER_STOP if draggable else Control.MOUSE_FILTER_IGNORE


func foot() -> Vector2:
	return position + Vector2(size.x / 2.0, size.y)


func set_foot(p: Vector2) -> void:
	position = p - Vector2(size.x / 2.0, size.y)


## delay초 뒤에 말풍선
func say(line: String, delay := 0.0) -> void:
	if _bubble_tw:
		_bubble_tw.kill()
	_bubble_tw = create_tween()
	_bubble_tw.tween_interval(delay)
	_bubble_tw.tween_callback(func():
		_text.text = line
		_bubble.visible = true
		_bubble.modulate.a = 1.0)
	_bubble_tw.tween_interval(BUBBLE_TIME)
	_bubble_tw.tween_property(_bubble, "modulate:a", 0.0, 0.25)
	_bubble_tw.tween_callback(func(): _bubble.visible = false)


func bubble_text() -> String:
	return _text.text if _bubble.visible else ""


## 발밑을 p까지 걸어감 (speed px/초, 걸음마다 살짝 통통). 끝나면 done
func walk_to(p: Vector2, speed: float, done: Callable = Callable()) -> void:
	stop_walk()
	var t := maxf(0.3, foot().distance_to(p) / speed)
	_walk_tw = create_tween()
	_walk_tw.tween_property(self, "position", p - Vector2(size.x / 2.0, size.y), t)
	if done.is_valid():
		_walk_tw.tween_callback(done)
	_hop_tw = create_tween().set_loops(maxi(1, roundi(t / 0.28)))
	_hop_tw.tween_property(_body, "position:y", -7.0, 0.14).set_ease(Tween.EASE_OUT)
	_hop_tw.tween_property(_body, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN)


func is_dragging() -> bool:
	return _press


func walking() -> bool:
	return _walk_tw != null and _walk_tw.is_running()


func stop_walk() -> void:
	for tw in [_walk_tw, _hop_tw]:
		if tw:
			tw.kill()
	_walk_tw = null
	_hop_tw = null
	_body.position.y = 0.0


## 톡 했을 때 쫄깃
func jelly() -> void:
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector2(1.14, 0.84), 0.07)
	tw.tween_property(_body, "scale", Vector2(0.92, 1.1), 0.1)
	tw.tween_property(_body, "scale", Vector2.ONE, 0.14)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			stop_walk()  # 걷던 중이면 그 자리에 멈춤
			_press = true
			_moved = false
			_grab = e.position
			z_index = 50
		elif _press:
			_press = false
			z_index = 0
			if _moved:
				dropped.emit(id, foot())
			else:
				tapped.emit(id)
		accept_event()
	elif e is InputEventMouseMotion and _press:
		if not _moved and (e.position - _grab).length() < DRAG_START:
			return
		_moved = true
		var p: Vector2 = position + e.position - _grab + Vector2(size.x / 2.0, size.y)
		set_foot(clamp_foot.call(p) if clamp_foot.is_valid() else p)
		accept_event()
