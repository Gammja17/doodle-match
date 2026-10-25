extends Control
## 길드 하우스: 길드 세션의 guild_house.tscn을 같은 Meta로 띄우고(setup), 닫으면 지도로


func _ready() -> void:
	SafeArea.apply(%Holder)
	AppSound.bgm("guild")
	var house: GuildHouse = load("res://scenes/guild/guild_house.tscn").instantiate()
	house.setup(AppState.meta())
	%Holder.add_child(house)
	house.closed.connect(back)


func back() -> void:
	AppState.go("map")
