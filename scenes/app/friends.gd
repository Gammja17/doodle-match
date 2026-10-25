extends Control









const FRIEND_TILE: = preload("res://scenes/app/parts/friend_tile.tscn")
const TREAT_NAME: = {"treat_a": "꿀 비스킷", "treat_b": "버섯 꼬치", "treat_c": "별사탕"}

const FRAME_MARGIN: = {1: [31, 30, 30, 27], 2: [33, 33, 32, 35], 3: [37, 38, 33, 36]}

var _id: = ""


func _ready() -> void :
	SafeArea.apply( %Screen)
	AppSound.bgm("map")
	for id in _all():
		var tile: FriendTile = FRIEND_TILE.instantiate()
		%Album.add_child(tile)
		tile.tilt(tile.get_index())
		tile.picked.connect(open_detail)
	%Back.pressed.connect(back)
	%Close.pressed.connect( %Detail.hide)
	%Up.pressed.connect(_level_up)
	%Recruit.pressed.connect(_recruit)
	%Overpaint.pressed.connect(_overpaint)
	%ArtTap.pressed.connect(open_art)
	%ArtViewer.closed.connect( func():
		if %ArtViewer.current_id() != _id:
			open_detail( %ArtViewer.current_id()))
	%FoldToggle.toggled.connect( func(on: bool):
		%Fold.visible = on
		%FoldToggle.text = "스킬·인연 이야기 %s" % ("접기 -" if on else "펼치기 +"))
	%Detail.hide()
	_refresh_album()



func _all() -> Array:
	return MetaConfig.shared().gacha.tiers.keys()



func _fid(rid: String) -> String:
	var map: = FriendLook.shared().web_map
	var i: = map.values().find(rid)
	return map.keys()[i] if i >= 0 else ""



func _track(rid: String) -> String:
	var f: = _fid(rid)
	return f if f != "" and (AppState.meta().owned(f) or not AppState.meta().owned(rid)) else rid


func _owned(rid: String) -> bool:
	var m: = AppState.meta()
	return m.owned(rid) or (_fid(rid) != "" and m.owned(_fid(rid)))


func _refresh_album() -> void :
	var m: = AppState.meta()
	var icons: = %Album.get_children()
	var all: = _all()
	for i in all.size():
		var rid: String = all[i]
		var t: = _track(rid)
		var tile: FriendTile = icons[i]
		var tier: = FriendLook.shared().tier(rid)
		tile.show_friend(rid, m.lv(t) if _owned(rid) else 0, ("%d성" % tier if tier > 0 else "") if _owned(rid) else _how_to_get(rid))
		tile.set_locked( not _owned(rid))
		tile.set_badge("강화!" if m.can_up(t) else "영입!" if _fid(rid) != "" and m.can_recruit(_fid(rid)) else "")
	%Count.text = "%d / %d" % [all.filter(_owned).size(), all.size()]
	%TopBar.refresh()



func _how_to_get(rid: String) -> String:
	var r: Dictionary = AppState.meta().cfg.recruit_by_id.get(AppState.meta().cfg.play_id(rid), {})
	match r.get("src", ""):
		"guest":
			return "국숫집 손님 · %s %d개" % [TREAT_NAME.get(r.treat, r.treat), int(r.count)]
		"treat":
			return "%s %d개" % [TREAT_NAME.get(r.treat, r.treat), int(r.count)]
		"route":
			return "%d판 이야기에서" % int(r.route)
		"story":
			return "%d장 이야기에서" % int(r.chapter)
		"after":
			return "%s 뒤 %d판" % [FriendLook.shared().name_of(r.friend_after), int(r.clears)]
	var tier: = FriendLook.shared().tier(rid)
	return "반짝 뽑기" if tier > 0 and rid in AppState.meta().cfg.gacha.sparkle.pool.get(str(tier), []) else "이야기에서"


func open_detail(id: String) -> void :
	var look: = FriendLook.shared()
	_id = look.rid(id)
	var m: = AppState.meta()
	var t: = _track(_id)
	var tier: = look.tier(_id)
	var attr: = look.attr(_id)
	var card: = look.card(_id)
	%CardArt.texture = card if card else look.sticker(_id)
	%CardArt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if card else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var f: NinePatchRect = %Frame
	f.texture = load("res://ui/screens/art/frame_%d.png" % maxi(1, tier))
	var mg: Array = FRAME_MARGIN[maxi(1, tier)]
	f.patch_margin_left = mg[0]
	f.patch_margin_top = mg[1]
	f.patch_margin_right = mg[2]
	f.patch_margin_bottom = mg[3]
	%Name.text = look.name_of(_id)
	%Job.text = look.job(_id)
	%AttrIcon.texture = FriendLook.attr_icon(attr)
	%Attr.text = FriendLook.attr_name(attr) + ("  %d성 %s" % [tier, FriendLook.TIER_NAME[tier]] if tier > 0 else "")
	%Attr.add_theme_color_override("font_color", FriendLook.attr_color(attr))
	var owned: = _owned(_id)
	var lv: = m.lv(t)
	%Lv.text = "Lv %d / %d" % [lv, m.max_lv(t)] if owned else "아직 없음 · " + _how_to_get(_id)
	var cost: = m.up_cost(t)
	var stats: Dictionary = m.cfg.friend_by_id.get(t, {})
	%Power.visible = owned and not stats.is_empty()
	if %Power.visible:
		%Power.text = "%s %s" % ["회복" if stats.has("heal") else "공격", _num(m.power(t))] + (" > %s" % _num(m.power(t, lv + 1)) if not cost.is_empty() else "")
	%ShardBar.visible = owned and not cost.is_empty()
	%Cost.visible = owned and not cost.is_empty()
	if owned and not cost.is_empty():
		var have: = int(m.data.shards.get(t, 0))
		%ShardBar.max_value = cost.shards
		%ShardBar.value = mini(have, cost.shards)
		%Cost.text = "조각 %d/%d · 코인 %d" % [have, cost.shards, cost.coins] + (" · %s %d" % [TREAT_NAME.get(cost.treat, cost.treat), cost.treat_n] if cost.treat != "" else "")
	%Up.visible = owned
	%Up.disabled = not m.can_up(t)
	%Up.text = "최고 레벨" if owned and cost.is_empty() else "강화"
	%Overpaint.visible = owned and tier > 0 and m.lv(_id) >= m.max_lv(_id) and m.max_lv(_id) < m.top_lv(_id)
	%Overpaint.disabled = not m.can_overpaint(_id)
	var fid: = _fid(_id)
	%Recruit.visible = not owned and m.cfg.recruit_by_id.get(fid, {}).get("by") == "treat"
	%Recruit.disabled = not m.can_recruit(fid)
	var unlock: Array = m.cfg.friends.skill_unlock_lv
	var rows: = %Skills.get_children()
	%Skills.visible = not stats.is_empty()
	for k in rows.size():
		if stats.is_empty():
			break
		var open: = owned and lv >= int(unlock[k])
		rows[k].text = "스킬 %d · 게이지 %d%s" % [k + 1, int(stats.skills[k].need), "" if open else "  (Lv%d에 열림)" % int(unlock[k])]
		rows[k].modulate.a = 1.0 if open else 0.45
	_fill_bonds(owned, lv)
	var was_open: bool = %Detail.visible
	%Detail.show()
	if not was_open:
		var sheet: Control = %Sheet
		sheet.modulate.a = 0.0
		await get_tree().process_frame
		AppFx.sheet_up(sheet)



func open_art() -> void :
	var owned: = _all().filter(_owned)
	var list: Array = owned if _id in owned else [_id]
	%ArtViewer.open(list, list.find(_id))


func _fill_bonds(owned: bool, lv: int) -> void :
	for c in %Bonds.get_children():
		c.queue_free()
	var bonds: = StoryDB.bonds(_id)
	%BondsTitle.visible = not bonds.is_empty()
	for b in bonds:
		var btn: = Button.new()
		var open: = owned and lv >= int(b.level)
		btn.text = b.title + ("" if open else "  (Lv%d에 열림)" % int(b.level))
		btn.disabled = not open
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 25)
		btn.pressed.connect( func():
			await StoryPlayer.play(b.trigger)
			AppState.mark_seen("story", b.trigger))
		%Bonds.add_child(btn)


static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else "%.1f" % v


func _level_up() -> void :
	if AppState.meta().level_up(_track(_id)):
		AppSound.sfx("level_up")
		_refresh_album()
		open_detail(_id)


func _recruit() -> void :
	if AppState.meta().recruit(_fid(_id)):
		AppSound.sfx("reward")
		_refresh_album()
		open_detail(_id)


func _overpaint() -> void :
	if AppState.meta().overpaint(_id):
		AppSound.sfx("level_up")
		open_detail(_id)


func back() -> void :
	if %ArtViewer.visible:
		%ArtViewer.close()
	elif %Detail.visible:
		%Detail.hide()
	else:
		AppState.go("map")
