extends VBoxContainer
## 파밍 중에만 보이는 보스 조작 (GDD 3절): 보스 도전(취소) 버튼과 자동 재도전 토글.
## Game의 시그널을 받아 표시만 하고, 누르면 Game의 함수를 부른다. 상수는 배치용이다.

const CHALLENGE_SIZE := Vector2(300, 80)
const AUTO_SIZE := Vector2(300, 56)
const GAP: int = 8

var _challenge: Button
var _auto: Button


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	_challenge = Button.new()
	_challenge.custom_minimum_size = CHALLENGE_SIZE
	_challenge.theme_type_variation = "AccentButton"
	_challenge.pressed.connect(Game.challenge_boss)
	add_child(_challenge)
	_auto = Button.new()
	_auto.toggle_mode = true
	_auto.custom_minimum_size = AUTO_SIZE
	_auto.toggled.connect(Game.set_auto_retry)
	add_child(_auto)
	Game.farming_changed.connect(_on_farming_changed)
	Game.boss_queued_changed.connect(_refresh.unbind(1))
	Game.auto_retry_changed.connect(_refresh.unbind(1))
	_on_farming_changed(Game.farming)


func _on_farming_changed(farming: bool) -> void:
	visible = farming
	_refresh()


func _refresh() -> void:
	_challenge.text = "보스 대기 중 (취소)" if Game.boss_queued else "보스 도전"
	_auto.set_pressed_no_signal(Game.auto_retry)
	_auto.text = "자동 재도전: 켬" if Game.auto_retry else "자동 재도전: 끔"
