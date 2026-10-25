extends HBoxContainer
## 위 재화 칩(포스트잇): 하트·다음 하트까지 시간(다 차면 MAX), 코인, 별가루·뽑기 티켓(있을 때만). 1초마다 메타에서 다시 읽음.
## 웹게임처럼 숫자는 세지 않고 바로 바뀜. 코인이 늘면 코인 칩만 1.25배로 톡 (300ms)
## show_extra = false면 하트·코인만 (웹 헤더처럼; 가게에서만 별가루·티켓까지)

@export var show_extra := false

var _coins := -1


func _ready() -> void:
	%Tick.timeout.connect(refresh)
	refresh()


func refresh() -> void:
	var m := AppState.meta()
	var h := m.hearts()
	%Hearts.text = "∞" if m.unlimited() else str(h)
	var wait := m.heart_wait_ms() / 1000
	%HeartWait.text = "%d:%02d" % [wait / 60, wait % 60] if wait > 0 and not m.unlimited() else "MAX"
	var coins: int = m.data.coins
	%Coins.text = str(coins)
	if _coins >= 0 and coins > _coins:
		AppFx.pop(%CoinChip)
	_coins = coins
	%Dust.text = str(m.dust())
	%DustChip.visible = show_extra
	var t: int = m.data.tickets + int(m.data.get("sparkle_tickets", 0))
	%Tickets.text = str(t)
	%TicketChip.visible = show_extra and t > 0
