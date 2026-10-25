class_name RamenRow
extends PanelContainer



signal pressed(id: String)

var id: = ""


func _ready() -> void :
	%Ticket.pressed.connect( func(): pressed.emit(id))


func setup(p_id: String, icon: Texture2D, title: String, desc: String, ticket: String, kind: = "buy", extra: = "") -> void :
	id = p_id
	%Icon.texture = icon
	%Name.text = title
	%Desc.text = desc
	%Extra.text = extra
	%Extra.visible = extra != ""
	%Ticket.text = ticket
	%Ticket.disabled = kind == "lock"
	%Ticket.theme_type_variation = &"AccentButton" if kind == "free" else &"MiniButton" if kind == "use" else &""
