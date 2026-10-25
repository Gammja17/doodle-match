class_name StageNode
extends Control




signal chosen(n: int)

const STAR_ON: = preload("res://ui/screens/art/star_on.png")
const STAR_OFF: = preload("res://ui/screens/art/star_off.png")

var n: = 0
var open: = false
var _loops: Array[Tween] = []


func _ready() -> void :
	%Sticker.pressed.connect(_on_pressed)


func _on_pressed() -> void :
	if open:
		chosen.emit(n)
	else:
		AppSound.sfx("error")
		AppFx.no( %Sticker)


func setup(p_n: int, m: Meta) -> void :
	n = p_n
	open = RouteInfo.is_open(m, n)
	var stars: = RouteInfo.stars(m, n)
	var level: String = RouteInfo.stage(n).level
	var b: Button = %Sticker
	b.text = str(n)
	b.theme_type_variation = &"StageLocked" if not open else &"StageBattle" if RouteInfo.is_battle(n) else &"StageHard" if level != "normal" else &"StageNode"
	%Battle.visible = RouteInfo.is_battle(n) and open
	var row: = %Stars.get_children()
	for i in row.size():
		row[i].texture = STAR_ON if i < stars else STAR_OFF
	%Stars.visible = open
	for t in _loops:
		t.kill()
	_loops.clear()
	b.scale = Vector2.ONE
	var here: TextureRect = %Here
	here.visible = open and stars == 0
	if here.visible:
		var hero: String = m.cfg.friends.starters[0]
		var party: = AppState.party()
		if not m.owned(hero):
			hero = party[0] if not party.is_empty() else ""
		here.texture = FriendLook.shared().sticker(hero) if hero != "" else null
		_start_loops.call_deferred()


func _start_loops() -> void :
	if not is_inside_tree() or not %Here.visible:
		return
	_loops.append(AppFx.pulse( %Sticker))
	_loops.append(AppFx.hop( %Here, 1000.0))
