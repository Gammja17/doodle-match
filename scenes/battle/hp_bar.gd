class_name HpBar
extends Control




const GHOST_HOLD: = 0.25
const GHOST_FALL: = 0.4

@export var fill_variation: = &"HpFill"
@export var low_warn: = false

var max_value: = 100.0:
	set(v):
		max_value = v
		if is_node_ready():
			_bar.max_value = v
			_ghost.max_value = v
			_show()
var value: float:
	get:
		return _bar.value if is_node_ready() else _value
	set(v):
		set_hp(v)

var _value: = 0.0
var _ghost_tw: Tween
var _pulse: Tween

@onready var _bar: ProgressBar = $Bar
@onready var _ghost: ProgressBar = $Ghost
@onready var _text: Label = $Text


func _ready() -> void :
	_bar.theme_type_variation = fill_variation
	_bar.max_value = max_value
	_ghost.max_value = max_value
	_bar.value = _value
	_ghost.value = _value
	_show()


func set_hp(v: float) -> void :
	if not is_node_ready():
		_value = v
		return
	var old: = _bar.value
	if v == old:
		return
	_bar.value = v
	if _ghost_tw:
		_ghost_tw.kill()
	if v < old:
		_ghost_tw = create_tween()
		_ghost_tw.tween_interval(GHOST_HOLD)
		_ghost_tw.tween_property(_ghost, "value", v, GHOST_FALL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_ghost.value = v
	_show()


func _show() -> void :
	_text.text = "%d / %d" % [roundi(_bar.value), roundi(max_value)]
	if not low_warn:
		return
	var low: = _bar.value <= max_value * 0.3
	_bar.theme_type_variation = &"HpFillLow" if low else fill_variation
	if low == (_pulse != null):
		return
	if low:
		_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse.tween_property(self, "scale", Vector2.ONE * 1.04, 0.4)
		_pulse.tween_property(self, "scale", Vector2.ONE, 0.4)
	else:
		_pulse.kill()
		_pulse = null
		scale = Vector2.ONE
