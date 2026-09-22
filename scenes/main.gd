extends Control
## 세로 화면 전체 (GDD 9절). 상단 바, 전투 화면, 스킬 바, 구매 배수, 탭 패널을 위에서부터 쌓는다.

const TAB_TITLES: PackedStringArray = ["용사", "동료", "회귀", "설정"]

const OFFLINE_POPUP_SIZE := Vector2i(600, 320)

@onready var _tabs: TabContainer = $Layout/Tabs

var _offline_dialog: AcceptDialog


func _ready() -> void:
	for i in TAB_TITLES.size():
		_tabs.set_tab_title(i, TAB_TITLES[i])
	_offline_dialog = AcceptDialog.new()
	_offline_dialog.title = "오프라인 보상"
	_offline_dialog.ok_button_text = "확인"
	add_child(_offline_dialog)
	Save.offline_reward.connect(_on_offline_reward)


## 돌아오면 비운 시간과 받은 골드를 먼저 보여준다 (GDD 8·9절). 동료가 없어 받을 게 없으면 띄우지 않는다
func _on_offline_reward(seconds: float, gold: float) -> void:
	if gold <= 0.0:
		return
	_offline_dialog.dialog_text = "자리를 비운 %s 동안\n동료들이 골드 %s을 모았습니다" % [
		Num.format_duration(seconds), Num.format(gold)]
	_offline_dialog.popup_centered(OFFLINE_POPUP_SIZE)
