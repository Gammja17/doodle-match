class_name AppPrefs
extends RefCounted




const PATH: = "user://app.cfg"
const DEFAULTS: = {vibration = true, language = "ko", fast_play = false, skill_cutin = true}


static func get_value(key: String, fallback: Variant = null) -> Variant:
	var cfg: = ConfigFile.new()
	cfg.load(PATH)
	return cfg.get_value("app", key, DEFAULTS.get(key, fallback))


static func set_value(key: String, value: Variant) -> void :
	var cfg: = ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("app", key, value)
	cfg.save(PATH)
