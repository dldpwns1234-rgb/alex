extends Control
## 전투 화면 왼쪽 위의 시련의 탑 입구 (GDD 7.10절): 입장권 수가 붙은 버튼, 탑 안에서는 "나가기". 역대 최고 100 전에는 보이지 않는다.
## Tower의 함수만 부르고 표시만 한다. 상수는 배치용이다.

const BUTTON_SIZE := Vector2(170, 56)
const CONFIRM_SIZE := Vector2i(600, 380)

var _button: Button
var _confirm: ConfirmationDialog


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = Button.new()
	_button.custom_minimum_size = BUTTON_SIZE
	_button.clip_text = true
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "시련의 탑"
	_confirm.ok_button_text = "도전한다"
	_confirm.cancel_button_text = "취소"
	_confirm.dialog_autowrap = true
	_confirm.confirmed.connect(Tower.enter)
	add_child(_confirm)
	Tower.tower_changed.connect(_refresh)
	Game.tower_changed.connect(_refresh.unbind(1))
	Game.monster_spawned.connect(_refresh.unbind(2))
	Game.monster_killed.connect(_refresh.unbind(1))
	Game.boss_failed.connect(_refresh)
	Achievements.stat_changed.connect(_refresh.unbind(2))
	_refresh()


func _on_pressed() -> void:
	if Game.in_tower:
		Tower.leave()
		return
	if not Tower.can_enter():
		return
	var next := Tower.best_floor + 1
	_confirm.dialog_text = "시련의 탑 %d층에 도전합니다.\n%d초 안에 몬스터 %d마리를 잡으면 다음 층으로 이어집니다.\n입장권 1장을 씁니다 (남은 %d장, 하루 %d장).\n\n첫 돌파 보상: 강화석 %s, %d층마다 운명의 실" % [
		next, roundi(Balance.TOWER_TIME_LIMIT), Balance.MONSTERS_PER_STAGE, Tower.tickets, Balance.TOWER_TICKETS_PER_DAY,
		Num.format(Balance.tower_stones(next)), Balance.TOWER_THREAD_FLOOR_STEP]
	_confirm.popup_centered(CONFIRM_SIZE)


func _refresh() -> void:
	visible = Tower.is_unlocked()
	if Game.in_tower:
		_button.text = "%d층 · 나가기" % Tower.floor
		_button.disabled = false
		_button.theme_type_variation = ""
		return
	_button.text = "탑 · 입장권 %d" % Tower.tickets
	_button.disabled = not Tower.can_enter()
	_button.theme_type_variation = "AccentButton" if not _button.disabled else ""
