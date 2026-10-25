class_name AppState
extends RefCounted







const SCREENS: = {
	title = "res://scenes/app/title.tscn", 
	map = "res://scenes/app/map.tscn", 
	prep = "res://scenes/app/prep.tscn", 
	puzzle = "res://scenes/app/puzzle_stage.tscn", 
	battle = "res://scenes/app/battle_stage.tscn", 
	result = "res://scenes/app/result.tscn", 
	friends = "res://scenes/app/friends.tscn", 
	shop = "res://scenes/app/shop.tscn", 
	guild = "res://scenes/app/guild_screen.tscn", 
	ramen = "res://scenes/app/ramen.tscn", 
	settings = "res://scenes/app/settings.tscn", 
}
const TEAM_SIZE: = 5
const JOIN_CARD: = preload("res://scenes/app/parts/join_card.tscn")
const KEY: = &"app_state"



static func _s() -> Dictionary:
	var root: = (Engine.get_main_loop() as SceneTree).root
	if not root.has_meta(KEY):
		root.set_meta(KEY, {save_path = SaveStore.PATH, args = {}, chapter = -1, meta = null})
		var runner: = AppRunner.new()
		runner.name = "AppRunner"
		root.add_child.call_deferred(runner)
	return root.get_meta(KEY)


static func meta() -> Meta:
	var s: = _s()
	if s.meta == null:
		s.meta = Meta.load_game(s.save_path)
	return s.meta



static func reload() -> void :
	_s().meta = null
	_s().chapter = -1



static func use_save(path: String) -> void :
	_s().save_path = path
	reload()


static func args() -> Dictionary:
	return _s().args


static func chapter() -> int:
	return _s().chapter


static func set_chapter(ch: int) -> void :
	_s().chapter = ch



static func go(screen: String, p_args: = {}) -> void :
	_s().args = p_args
	var r: = runner()
	if r and r.is_inside_tree():
		r.change(SCREENS[screen])
	else:
		(Engine.get_main_loop() as SceneTree).change_scene_to_file(SCREENS[screen])


static func runner() -> AppRunner:
	_s()
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AppRunner")



static func toast(text: String) -> void :
	var r: = runner()
	if r and r.is_node_ready():
		r.toast(text)
	else:
		_s().get_or_add("toasts", []).append(text)


static func save() -> void :
	var m: = meta()
	if m.save_path != "":
		m.save()




static func party() -> Array:
	var m: = meta()
	var saved: Array = m.data.get("party", m.cfg.friends.default_team)
	var p: = saved.filter( func(id): return m.owned(id))
	if p.is_empty():
		p = m.cfg.friends.starters.filter( func(id): return m.owned(id))
	return p.slice(0, TEAM_SIZE)


static func set_party(ids: Array) -> void :
	meta().data.party = ids.slice(0, TEAM_SIZE)
	save()




static func app() -> Dictionary:
	var a: Dictionary = meta().data.get_or_add("app", {})
	for k in ["story", "tips"]:
		if not a.has(k):
			a[k] = {}
	if not a.has("playing"):
		a.playing = ""
	return a


static func seen(kind: String, key: String) -> bool:
	return app()[kind].get(key, false)


static func mark_seen(kind: String, key: String) -> void :
	app()[kind][key] = true
	save()



static func begin_stage(ref: String) -> void :
	app().playing = ref
	save()


static func end_stage() -> void :
	app().playing = ""




static func story_once(trigger: String) -> void :
	if seen("story", trigger) or not StoryPlayer.has(trigger):
		return
	AppSound.bgm("story")
	var joined: = []
	StoryPlayer.on_join = func(id: String):
		if meta().recruit(id):
			joined.append(meta().cfg.play_id(id))
	await StoryPlayer.play(trigger)
	StoryPlayer.on_join = Callable()
	mark_seen("story", trigger)
	await join_cards(joined)



static func join_cards(ids: Array) -> void :
	var tree: = Engine.get_main_loop() as SceneTree
	for id in ids:
		var fresh: Array = app().get_or_add("new", [])
		if not id in fresh:
			fresh.append(id)
		save()
		var full: = party().size() >= TEAM_SIZE
		var layer: = CanvasLayer.new()
		layer.layer = 52
		layer.name = "JoinCard"
		tree.root.add_child(layer)
		var card: JoinCard = JOIN_CARD.instantiate()
		layer.add_child(card)
		await tree.process_frame
		card.setup(id, full)
		var add: bool = await card.done
		layer.queue_free()
		if add and not full and not id in party():
			set_party(party() + [id])
