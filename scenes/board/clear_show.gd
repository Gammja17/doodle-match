class_name ClearShow
extends Control



@onready var _dim: ColorRect = $Dim
@onready var _stamp: Label = $Stamp
@onready var _stamp_pic: TextureRect = $StampPic
@onready var _hero: TextureRect = $Hero


func play(text: String, hero: Texture2D, fx: FxLayer) -> void :
	_stamp.text = text
	var pic: = WordArt.of(text)
	_stamp_pic.texture = pic
	_stamp_pic.visible = pic != null
	_stamp.visible = pic == null
	var stamp: Control = _stamp_pic if pic else _stamp
	_hero.texture = hero
	show()
	modulate.a = 1.0
	stamp.modulate.a = 0.0
	_hero.modulate.a = 0.0
	stamp.pivot_offset = stamp.size / 2
	_dim.modulate.a = 0.0
	_dim.create_tween().tween_property(_dim, "modulate:a", 0.35, 0.2)
	fx.confetti()
	get_tree().create_timer(0.25).timeout.connect(fx.confetti.bind(10))
	await get_tree().create_timer(0.25).timeout
	await Juice.play(stamp, stamp.position, [
		{s = 2.6, r = -24.0, a = 0.0}, {t = 0.7, s = 0.88, r = -10.0, a = 1.0}, {s = 1.0, r = -12.0, a = 1.0}, 
	], 320.0, [0.6, 0.0, 0.9, 0.6]).finished
	fx.sfx("hit", 0.7)
	fx.jingle("win")
	fx.shake(12, 320)
	fx.flash(Color.WHITE, 0.4)
	fx.burst(stamp.get_global_rect().get_center(), Color("e2543f"), 16)
	await get_tree().create_timer(0.42).timeout
	var h: = _hero.size.y
	Juice.play(_hero, _hero.position, [{y = h * 1.2, r = -8.0, a = 1.0}, {t = 0.7, y = - h * 0.06, r = 3.0}, {}], 380.0, "ease-out")
	fx.sfx("pop", 1.3)
	await get_tree().create_timer(1.3).timeout
	await create_tween().tween_property(self, "modulate:a", 0.0, 0.22).finished
	hide()
