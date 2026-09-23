extends Control
## 세로 화면 전체 (GDD 9절). 상단 바, 전투 화면, 스킬 바, 구매 배수, 탭 내비게이션과 패널을 위에서부터 쌓는다.
## 내비게이션이 고른 패널만 보이고, 살 수 있는 단련이 있으면 단련 탭에 점을 찍는다.

const TRAINING_TAB: int = 2
const OFFLINE_POPUP_SIZE := Vector2i(600, 320)

@onready var _nav: HBoxContainer = $Layout/Nav
@onready var _panels: MarginContainer = $Layout/Panels

var _offline_dialog: AcceptDialog


func _ready() -> void:
	_offline_dialog = AcceptDialog.new()
	_offline_dialog.title = "오프라인 보상"
	_offline_dialog.ok_button_text = "확인"
	add_child(_offline_dialog)
	Save.offline_reward.connect(_on_offline_reward)
	_nav.tab_selected.connect(_show_panel)
	_nav.select(0)
	Game.gold_changed.connect(_refresh_training_badge.unbind(1))
	Training.training_changed.connect(_refresh_training_badge.unbind(2))
	Party.hero_changed.connect(_refresh_training_badge.unbind(1))
	Party.companion_changed.connect(_refresh_training_badge.unbind(2))
	_refresh_training_badge()


func _show_panel(index: int) -> void:
	for i in _panels.get_child_count():
		(_panels.get_child(i) as Control).visible = i == index


func _refresh_training_badge() -> void:
	_nav.set_badge(TRAINING_TAB, Training.any_affordable())


## 돌아오면 비운 시간과 받은 골드를 먼저 보여준다 (GDD 8·9절). 동료가 없어 받을 게 없으면 띄우지 않는다
func _on_offline_reward(seconds: float, gold: float) -> void:
	if gold <= 0.0:
		return
	_offline_dialog.dialog_text = "자리를 비운 %s 동안\n동료들이 골드 %s을 모았습니다" % [
		Num.format_duration(seconds), Num.format(gold)]
	_offline_dialog.popup_centered(OFFLINE_POPUP_SIZE)
