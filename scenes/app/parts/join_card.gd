class_name JoinCard
extends Control







signal done(add: bool)

const STRINGS: = "res://data/strings/ko.json"

static var _ko: = {}

var id: = ""


func _ready() -> void :
	%Yes.pressed.connect(_close.bind(true))
	%No.pressed.connect(_close.bind(false))


func setup(p_id: String, party_full: = false) -> void :
	id = p_id
	var look: = FriendLook.shared()
	var rid: = look.rid(p_id)
	%Sticker.texture = look.sticker(p_id)
	%Name.text = look.name_of(p_id)
	%Job.text = look.job(p_id)
	%Intro.text = _s("char.%s.intro" % rid)
	%Intro.visible = %Intro.text != ""
	var sk: = _s("char.%s.skill1.name" % rid)
	%Skill.visible = sk != ""
	%SkillName.text = "스킬 · " + sk
	%SkillDesc.text = _s("char.%s.skill1.desc" % rid)
	%Ask.text = "편성이 꽉 찼어. 친구 화면에서 바꿀 수 있어" if party_full else "편성에 넣을까?"
	%Yes.text = "좋아" if party_full else "넣을래"
	%No.visible = not party_full
	_appear()


func _appear() -> void :
	%Blocker.show()
	get_tree().create_timer(0.7).timeout.connect( %Blocker.hide)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	AppSound.sfx("star")
	var st: Control = %Sticker
	st.pivot_offset = st.size / 2
	st.scale = Vector2.ONE * 0.3
	st.position.y += 60
	st.modulate.a = 0.0
	var y0: = st.position.y - 60
	var tw: = create_tween().set_parallel()
	tw.tween_property(st, "modulate:a", 1.0, 0.31).set_delay(0.12)
	tw.tween_property(st, "scale", Vector2.ONE * 1.12, 0.31).set_delay(0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(st, "position:y", y0 - 14, 0.31).set_delay(0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(st, "scale", Vector2.ONE, 0.21).set_delay(0.43)
	tw.tween_property(st, "position:y", y0, 0.21).set_delay(0.43)
	var tag: Control = %Tag
	tag.pivot_offset = tag.size / 2
	tag.scale = Vector2.ONE * 2.4
	tag.rotation_degrees = -14.0
	tag.modulate.a = 0.0
	tw.tween_property(tag, "scale", Vector2.ONE, 0.3).set_delay(0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(tag, "rotation_degrees", -6.0, 0.3).set_delay(0.4)
	tw.tween_property(tag, "modulate:a", 1.0, 0.3).set_delay(0.4)
	var nm: Control = %Name
	nm.modulate.a = 0.0
	tw.tween_property(nm, "modulate:a", 1.0, 0.3).set_delay(0.56)


func _close(add: bool) -> void :
	AppSound.sfx("click")
	var tw: = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
	done.emit(add)


static func _s(key: String) -> String:
	if _ko.is_empty() and FileAccess.file_exists(STRINGS):
		_ko = JSON.parse_string(FileAccess.get_file_as_string(STRINGS))
	return String(_ko.get(key, ""))
