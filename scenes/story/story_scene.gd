class_name StoryScene
extends Control




signal finished(skipped: bool)

signal joined(id: String)

const DB: = preload("res://scripts/story/story_db.gd")
const ACTOR: = preload("res://scenes/story/story_actor.tscn")
const CHARS_PER_SEC: = 32.0
const BG_FADE: = 0.3
const PAUSE_AFTER: = {".": 0.18, "!": 0.18, "?": 0.18, "…": 0.25, ",": 0.08}

var cast: = {}
var steps: Array = []
var done: = false
var joined_ids: Array[String] = []

var bg_dir: String = DB.bg_path("").get_base_dir() + "/"
var bg_id: = ""

var _i: = 0
var _actors: = {}
var _typing: Tween
var _typing_label: Label
var _wait_gen: = 0
var _waiting: = false

@onready var _stage: Control = %Stage
@onready var _slots: = {left = %Left, right = %Right, left2 = %Left2, right2 = %Right2}
@onready var _bubble_box: Control = %BubbleBox
@onready var _text: Label = %Text
@onready var _name: Label = %Name
@onready var _tail: Node2D = %Tail
@onready var _next: Label = %Next
@onready var _narr: Label = %Narration
@onready var _title: Label = %Title
@onready var _skip: Button = %Skip
@onready var _bg_front: TextureRect = %BgA
@onready var _bg_back: TextureRect = %BgB

static var _bg_cache: = {}


func _ready() -> void :
	_skip.pressed.connect(skip)
	_bubble_box.visible = false
	_narr.visible = false
	_title.visible = false
	var blink: = create_tween().set_loops()
	blink.tween_property(_next, "modulate:a", 0.2, 0.4)
	blink.tween_property(_next, "modulate:a", 1.0, 0.4)



func start(scene: Dictionary, p_cast: Dictionary) -> void :
	cast = p_cast
	steps = scene.get("steps", [])
	_i = 0

	if not steps.is_empty() and DB.command_of(steps[0]) == "bg":
		_set_bg(steps[0].bg, false)
		_i = 1
	else:
		_set_bg(DB.default_bg(scene.get("trigger", "")), false)
	_run()



func advance() -> void :
	if done:
		return
	if _typing and _typing.is_valid() and _typing.is_running():
		_typing.kill()
		_typing_label.visible_ratio = 1.0
		_next.visible = true
		return
	if _waiting:
		_wait_gen += 1
		_waiting = false
	_run()


func skip() -> void :
	if done:
		return
	_finish(true)


func is_typing() -> bool:
	return _typing != null and _typing.is_valid() and _typing.is_running()


func actor(id: String) -> StoryActor:
	return _actors.get(id)


func _gui_input(e: InputEvent) -> void :
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)\
	or (e is InputEventScreenTouch and e.pressed):
		accept_event()
		advance()


func _unhandled_key_input(e: InputEvent) -> void :
	if e.is_action_pressed("ui_accept"):
		advance()



func _run() -> void :
	while _i < steps.size():
		var st: Dictionary = steps[_i]
		_i += 1
		var cmd: = DB.command_of(st)
		_apply(cmd, st)
		if cmd in DB.WAITS_TAP:
			return
		if cmd == "wait":
			_waiting = true
			get_tree().create_timer(float(st.wait)).timeout.connect(_on_wait_done.bind(_wait_gen))
			return
	_finish(false)


func _on_wait_done(gen: int) -> void :
	if gen != _wait_gen or not _waiting or done:
		return
	_waiting = false
	_run()


func _apply(cmd: String, st: Dictionary) -> void :
	var who = st[cmd]
	match cmd:
		"enter":
			_enter(who, st.at, st.get("face", "normal"))
		"exit":
			var a: StoryActor = _actors.get(who)
			_actors.erase(who)
			if a:
				a.peel_off(-1.0 if _side_of(a).begins_with("left") else 1.0)
		"emote":
			if _actors.has(who):
				_actors[who].set_face(st.face)
		"shake":
			if who == DB.SCREEN:
				_shake_screen()
			elif _actors.has(who):
				_actors[who].shake()
		"hop":
			if _actors.has(who):
				_actors[who].hop()
		"say":
			_say(who, st)
		"narr":
			_show_only(_narr)
			_narr.text = who
			_type(_narr)
			_dim_all()
		"join":
			_join(who)
		"bg":
			_set_bg(who, true)
		"title":
			_show_only(_title)
			_title.text = who + ("\n" + st.sub if st.has("sub") else "")
			_title.visible_ratio = 1.0
			_title.scale = Vector2.ONE * 1.3
			create_tween().tween_property(_title, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_dim_all()



func _set_bg(id: String, fade: bool) -> void :
	bg_id = id
	var tex: = _bg_texture(id)
	if tex == _bg_front.texture and _bg_front.visible == (tex != null):
		return
	var old: = _bg_front
	var new: = _bg_back
	new.get_parent().move_child(new, -1)
	new.texture = tex
	new.visible = tex != null
	_bg_front = new
	_bg_back = old
	if not fade:
		new.modulate.a = 1.0
		old.visible = false
		return
	new.modulate.a = 0.0
	var tw: = create_tween().set_parallel()
	tw.tween_property(new, "modulate:a", 1.0, BG_FADE)
	tw.tween_property(old, "modulate:a", 0.0, BG_FADE)
	tw.chain().tween_callback( func(): old.visible = false)


func _bg_texture(id: String) -> Texture2D:
	if id.is_empty():
		return null
	var path: = bg_dir + id + ".png"
	if not _bg_cache.has(path):
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path)
		elif FileAccess.file_exists(path):
			var img: = Image.load_from_file(ProjectSettings.globalize_path(path))
			if img and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
		_bg_cache[path] = tex
	return _bg_cache[path]


func _join(id: String) -> void :
	if id in joined_ids:
		return
	joined_ids.append(id)
	joined.emit(id)


func _enter(id: String, side: String, face: String) -> void :
	var info: Dictionary = cast.get(id, {name = id})
	var a: StoryActor = ACTOR.instantiate()
	var slot: Control = _slots[side]
	slot.add_child(a)

	var look: String = info.get("look", "front")
	a.setup(id, info, (side.begins_with("right") and look == "right") or (side.begins_with("left") and look == "left"))
	a.stick_on()
	if face != "normal":
		a.set_face(face)
	a.set_speaking(false)
	_actors[id] = a


func _say(id: String, st: Dictionary) -> void :
	_show_only(_bubble_box)
	var info: Dictionary = cast.get(id, {})
	_name.text = st.get("name", info.get("name", id))
	var speaker: StoryActor = _actors.get(id)
	for a in _actors.values():
		a.set_speaking(a == speaker)
	if speaker and st.has("face"):
		speaker.set_face(st.face)

	_tail.visible = speaker != null
	var left: = true
	if speaker:
		var slot: Control = speaker.get_parent()
		left = _side_of(speaker).begins_with("left")
		var cx: = slot.get_global_rect().get_center().x - _bubble_box.global_position.x
		_tail.position.x = clampf(cx, 70.0, _bubble_box.size.x - 70.0)
	_name.position.x = 12.0 if left else _bubble_box.size.x - _name.size.x - 12.0
	_name.rotation = -0.05 if left else 0.05
	_text.text = st.text
	_type(_text)


func _type(label: Label) -> void :
	if _typing and _typing.is_valid():
		_typing.kill()
	_typing_label = label
	label.visible_characters = 0
	_next.visible = false
	var n: = label.get_total_character_count()
	var txt: = label.text
	_typing = create_tween()
	for i in n:
		_typing.tween_callback( func(): label.visible_characters = i + 1).set_delay(1.0 / CHARS_PER_SEC)
		var ch: = txt.substr(i, 1) if i < txt.length() else ""
		if PAUSE_AFTER.has(ch) and i < n - 1:
			_typing.tween_interval(PAUSE_AFTER[ch])
	_typing.tween_callback( func(): _next.visible = true)


func _show_only(node: Control) -> void :
	for n in [_bubble_box, _narr, _title]:
		n.visible = n == node


func _dim_all() -> void :
	for a in _actors.values():
		a.set_speaking(false)


func _side_of(a: StoryActor) -> String:
	for side in _slots:
		if _slots[side] == a.get_parent():
			return side
	return "left"


func _shake_screen() -> void :
	var tw: = create_tween()
	for p in [Vector2(16, -8), Vector2(-14, 10), Vector2(10, -6), Vector2(-6, 4), Vector2.ZERO]:
		tw.tween_property(_stage, "position", p, 0.045)


func _finish(skipped: bool) -> void :
	if done:
		return
	done = true
	_wait_gen += 1
	if _typing and _typing.is_valid():
		_typing.kill()

	for k in range(_i, steps.size()):
		if DB.command_of(steps[k]) == "join":
			_join(steps[k].join)
	finished.emit(skipped)
