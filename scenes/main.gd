extends Control
## 세로 화면 전체 (GDD 9절). 상단 바, 전투 화면, 스킬 바, 구매 배수, 탭 패널을 위에서부터 쌓는다.

const TAB_TITLES: PackedStringArray = ["용사", "동료", "단련", "회귀", "설정"]
const TRAINING_TAB: int = 2
# 살 수 있는 단련이 있을 때 단련 탭 위에 찍는 점. 탭 이름에 붙이면 탭 폭이 바뀌어 흔들리므로 따로 그린다
const BADGE_SIZE := Vector2(12, 12)
const BADGE_COLOR := Color("ffe66d")
const BADGE_INSET := Vector2(4, 4)  # 탭 오른쪽 위 모서리에서 안쪽으로

const OFFLINE_POPUP_SIZE := Vector2i(600, 320)

@onready var _tabs: TabContainer = $Layout/Tabs

var _offline_dialog: AcceptDialog
var _badge: Panel


func _ready() -> void:
	for i in TAB_TITLES.size():
		_tabs.set_tab_title(i, TAB_TITLES[i])
	_offline_dialog = AcceptDialog.new()
	_offline_dialog.title = "오프라인 보상"
	_offline_dialog.ok_button_text = "확인"
	add_child(_offline_dialog)
	Save.offline_reward.connect(_on_offline_reward)
	_badge = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_COLOR
	style.set_corner_radius_all(roundi(BADGE_SIZE.x * 0.5))
	_badge.add_theme_stylebox_override("panel", style)
	_badge.size = BADGE_SIZE
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	_tabs.get_tab_bar().resized.connect(_place_badge)
	_place_badge.call_deferred()
	Game.gold_changed.connect(_refresh_training_badge.unbind(1))
	Training.training_changed.connect(_refresh_training_badge.unbind(2))
	Party.hero_changed.connect(_refresh_training_badge.unbind(1))
	Party.companion_changed.connect(_refresh_training_badge.unbind(2))
	_refresh_training_badge()


func _refresh_training_badge() -> void:
	_badge.visible = Training.any_affordable()


## 단련 탭의 오른쪽 위 모서리에 점을 놓는다
func _place_badge() -> void:
	var bar := _tabs.get_tab_bar()
	var rect := bar.get_tab_rect(TRAINING_TAB)
	var corner := bar.global_position + rect.position + Vector2(rect.size.x, 0.0)
	_badge.global_position = corner + Vector2(-BADGE_SIZE.x - BADGE_INSET.x, BADGE_INSET.y)


## 돌아오면 비운 시간과 받은 골드를 먼저 보여준다 (GDD 8·9절). 동료가 없어 받을 게 없으면 띄우지 않는다
func _on_offline_reward(seconds: float, gold: float) -> void:
	if gold <= 0.0:
		return
	_offline_dialog.dialog_text = "자리를 비운 %s 동안\n동료들이 골드 %s을 모았습니다" % [
		Num.format_duration(seconds), Num.format(gold)]
	_offline_dialog.popup_centered(OFFLINE_POPUP_SIZE)
