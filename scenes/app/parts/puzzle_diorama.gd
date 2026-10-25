class_name PuzzleDiorama
extends Control





const ACTOR: = preload("res://scenes/story/story_actor.tscn")
const LEAD: = "grenn"
const STRIP: = "res://art/puzzle_strips/ch%02d.jpg"

var _actors: Array[StoryActor] = []
var _worried: = false


func _ready() -> void :
	resized.connect(_fit)



func setup(ch: int, ids: Array) -> void :
	var strip: = STRIP % (ch + 1)
	if ResourceLoader.exists(strip):
		%Land.texture = load(strip)
	else:
		var book: = clampi(int(ch / 6.0), 0, 4)
		var at: = AtlasTexture.new()
		at.atlas = load("res://ui/screens/art/bg_map_%d.jpg" % (book + 1))
		at.set_meta("band", 0.12 + (ch % 6) * 0.11)
		%Land.texture = at
	var cast: = StoryDB.cast()
	var look: = FriendLook.shared()
	var who: Array = [LEAD]
	for id in ids:
		var aid: = look.art_id(id)
		if who.size() < 3 and not aid in who:
			who.append(aid)
	for aid: String in who:
		var a: StoryActor = ACTOR.instantiate()
		%Actors.add_child(a)
		var info: Dictionary = cast.get(aid, {})
		if info.is_empty():
			info = {name = look.name_of(aid), sticker = "res://scenes/app/temp_art/chars/%s_sticker.png" % aid}
		a.setup(aid, info, false)
		_actors.append(a)
	_fit()
	_drift()



func _fit() -> void :
	var at: = %Land.texture as AtlasTexture
	if at and at.atlas and size.y > 0:
		var w: = float(at.atlas.get_width())
		var h: = w * size.y / maxf(1.0, size.x)
		var y: = clampf(float(at.get_meta("band", 0.5)) * at.atlas.get_height(), 0.0, at.atlas.get_height() - h)
		at.region = Rect2(0, y, w, h)
	var ah: = minf(size.y * 0.86, size.x * 0.3)
	for a in _actors:
		a.custom_minimum_size = Vector2(ah * 0.6, ah)
	%Actors.offset_top = - ah - 12.0
	var s: Control = %Scribble
	s.custom_minimum_size = Vector2.ONE * minf(140.0, size.y * 0.62)



func _drift() -> void :
	var w: float = %Doodles.size.x
	for pair in [["Cloud1", 40.0], ["Cloud2", 55.0], ["Bird", 18.0]]:
		var n: Control = %Doodles.get_node(pair[0])
		var start: = n.position.x
		var tw: = n.create_tween().set_loops()
		tw.tween_property(n, "position:x", w + 10.0, pair[1] * (w + 10.0 - start) / (w + n.size.x))
		tw.tween_callback( func(): n.position.x = - n.size.x)
		tw.tween_property(n, "position:x", start, pair[1] * (start + n.size.x) / (w + n.size.x))
	AppFx.loop( %Scribble, [{r = -4.0}, {r = 4.0}, {r = -4.0}], 1600.0)



func combo() -> void :
	for i in _actors.size():
		get_tree().create_timer(i * 0.08).timeout.connect(_actors[i].hop)



func surprised() -> void :
	for a in _actors:
		a.set_face("surprised")
	get_tree().create_timer(0.8).timeout.connect( func():
		if is_inside_tree():
			for a in _actors:
				a.set_face("scared" if _worried else "normal"))



func worry(on: bool) -> void :
	if on == _worried:
		return
	_worried = on
	for a in _actors:
		a.set_face("scared" if on else "normal")



func cheer() -> void :
	_worried = false
	for a in _actors:
		a.set_face("happy")
		a.hop()
		get_tree().create_timer(0.3).timeout.connect(a.hop)
	AppFx.play( %Scribble, [{s = 1.0, a = 1.0}, {t = 0.3, s = 1.15, a = 1.0}, {s = 0.2, a = 0.0}], 520, "ease-in")
