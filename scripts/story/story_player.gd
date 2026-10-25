class_name StoryPlayer
extends RefCounted







const DB: = preload("res://scripts/story/story_db.gd")
const SCENE: = preload("res://scenes/story/story_scene.tscn")
const LAYER: = 50


static var last_skipped: = false

static var last_joined: Array[String] = []

static var on_join: Callable


static func has(trigger: String) -> bool:
	return not DB.scene(trigger).is_empty()


static func play(trigger: String, host: Node = null) -> bool:
	var data: = DB.scene(trigger)
	last_skipped = false
	last_joined = []
	if data.is_empty():
		return false
	if host == null:
		host = (Engine.get_main_loop() as SceneTree).root
	var layer: = CanvasLayer.new()
	layer.layer = LAYER
	layer.name = "Story"
	host.add_child(layer)
	var view: Control = SCENE.instantiate()
	layer.add_child(view)
	view.joined.connect(_on_joined)
	view.start(data, DB.cast())
	last_skipped = await view.finished
	layer.queue_free()
	return true


static func _on_joined(id: String) -> void :
	last_joined.append(id)
	if on_join.is_valid():
		on_join.call(id)
