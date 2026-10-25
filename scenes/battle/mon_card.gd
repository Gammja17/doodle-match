class_name MonCard
extends VBoxContainer



signal picked(index: int)

var index: = 0

@onready var _attr: TextureRect = $Head / Attr
@onready var _name: Label = $Head / Name
@onready var _stand: Control = $Stand
@onready var _shadow: Panel = $Stand / Shadow
@onready var _art: TextureRect = $Stand / Art
@onready var _hp: HpBar = $Hp
@onready var _cd: Label = $Cd
@onready var _mark: Label = $Mark


func setup(m: Dictionary, art: BattleArt) -> void :
	index = m.index
	var w: Dictionary = m.w
	var role: = BattleData.enemy_skill(w.enemy)
	if w.enemy in BattleGame.THROWS_STICKY:
		role = "포스트잇 던지기"
	_attr.texture = art.attr_icons.get(w.attr)
	_name.text = BattleArt.ATTR_NAME.get(w.attr, w.attr) + (" 보스" if w.get("boss", false) else "")\
	+ ("\n" + BattleArt.ROLE_NAME.get(role, role) if role != "" else "")
	_name.add_theme_color_override("font_color", BattleArt.ATTR_COLOR.get(w.attr, Color.BLACK))
	_art.texture = art.enemy_texture(w)
	if w.get("boss", false):
		_stand.custom_minimum_size *= 1.35
	_hp.max_value = m.max
	set_hp(m.hp)
	set_cd(m.cd)
	set_picked(false)
	if m.hp <= 0:
		modulate.a = 0.4
		_art.modulate.a = 0.0
		_shadow.modulate.a = 0.0


func set_hp(v: int) -> void :
	_hp.value = v


func shown_hp() -> float:
	return _hp.value


func set_cd(n: int) -> void :
	_cd.text = "공격까지 %d" % n


func set_picked(on: bool) -> void :
	_mark.modulate.a = 1.0 if on else 0.0



func art_center() -> Vector2:
	return _art.get_global_rect().get_center()



func hurt() -> void :
	var k: = size.x / 190.0
	_art.pivot_offset = _art.size / 2
	Juice.play(_art, _home(), [{b = 2.2}, {t = 0.3, x = -10 * k, sx = 0.9, sy = 1.08, b = 1.6}, {t = 0.65, x = 7 * k, sx = 1.05, sy = 0.95}, {b = 1.0}], 280.0, "ease")



func peck() -> void :
	_art.pivot_offset = _art.size / 2
	Juice.play(_art, _home(), [{}, {sx = 0.93, sy = 1.06, x = (randf() - 0.5) * 10.0, y = 2.0, b = 1.8}, {}], 120.0, "ease")



func lunge() -> void :
	var k: = size.x / 190.0
	_art.pivot_offset = _art.size / 2
	Juice.play(_art, _home(), [{}, {t = 0.35, y = 6 * k, sx = 1.1, sy = 0.88}, {t = 0.65, y = 30 * k, s = 1.4}, {}], 520.0, "ease-out")



func appear(delay: = 0.0) -> void :
	var k: = size.x / 190.0
	_art.pivot_offset = _art.size / 2
	Juice.play(_art, _home(), [{y = -220 * k, s = 0.6, a = 0.0}, {t = 0.6, sx = 1.15, sy = 0.85, a = 1.0}, {t = 0.8, y = -14 * k, sx = 0.95, sy = 1.05}, {}], 600.0, "ease-out", delay)
	_shadow.modulate.a = 0.0
	_shadow.create_tween().tween_property(_shadow, "modulate:a", 1.0, 0.36).set_delay(delay / 1000.0)



func die_big() -> void :
	var k: = size.x / 190.0
	_art.pivot_offset = _art.size / 2
	Juice.play(_art, _home(), [{b = 1.0, a = 1.0}, {t = 0.3, sx = 1.2, sy = 0.8, r = -6.0, b = 2.5}, {s = 0.2, r = 200.0, y = -60 * k, a = 0.0}], 650.0, "ease-in")
	_shadow.create_tween().tween_property(_shadow, "modulate:a", 0.0, 0.65)



func die_small() -> void :
	var k: = size.x / 190.0
	_art.pivot_offset = _art.size / 2
	Juice.play(_art, _home(), [{b = 2.0, a = 1.0}, {s = 0.2, r = 160.0, y = -40 * k, a = 0.0}], 480.0, "ease-in")
	_shadow.create_tween().tween_property(_shadow, "modulate:a", 0.0, 0.48)
	create_tween().tween_property(self, "modulate:a", 0.4, 0.48)


func _home() -> Vector2:
	if not has_meta("art_home"):
		set_meta("art_home", _art.position)
	return get_meta("art_home")


func _gui_input(e: InputEvent) -> void :
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(index)
