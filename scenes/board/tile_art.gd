class_name TileArt
extends Resource


@export var tiles: Array[Texture2D] = []
@export var eraser_h: Texture2D
@export var eraser_v: Texture2D
@export var pushpin: Texture2D
@export var crayon: Texture2D
@export var paper_plane: Texture2D
@export var sticky: Array[Texture2D] = []
@export var crumbs: Array[Texture2D] = []
@export var ink: Texture2D
@export var deliver: Texture2D
@export var tape: Texture2D
@export var cell: Texture2D
@export var highlight: Texture2D
@export var combo: Texture2D

@export var colors: Array[Color] = []

@export var pad: = 0.15

@export var item_mat: Material
@export var block_mat: Material
@export var tape_mat: Material


func texture_for(t: BoardTile) -> Texture2D:
	if t.block == Board.STICKY:
		return _layer(sticky, t.hp)
	if t.block == Board.CRUMBS:
		return _layer(crumbs, t.hp)
	if t.block == Board.INK:
		return ink
	if t.type == BoardTile.DELIVER:
		return deliver
	match t.special:
		Board.ERASER_H: return eraser_h
		Board.ERASER_V: return eraser_v
		Board.PUSHPIN: return pushpin
		Board.CRAYON: return crayon
		Board.PAPER_PLANE: return paper_plane
	return tiles[t.type % tiles.size()]



func material_for(t: BoardTile) -> Material:
	if t.block != &"":
		return block_mat
	if t.special != &"":
		return item_mat
	return null



func goal_icon(g: Dictionary) -> Texture2D:
	match g.k:
		"sticky": return _layer(sticky, 1)
		"crumbs": return _layer(crumbs, 1)
		"ink": return ink
		"tape": return tape
		"highlighter": return highlight
		"deliver": return deliver
		"tile": return tiles[g.tile % tiles.size()]
	return null


func _layer(list: Array[Texture2D], hp: int) -> Texture2D:
	return list[clampi(hp, 1, list.size()) - 1]
