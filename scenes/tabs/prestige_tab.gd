extends MarginContainer
## 회귀 탭 (GDD 7절·9절): 칩 줄로 층을 나눈다 (방장 2026-10-03: 한 줄로 이어 붙여 스크롤이 너무 길었다).
## [회귀] 결정·회귀 버튼·기억의 상점(memory_panel.gd) · [환생] 운명의 실·운명의 상점(rebirth_panel.gd) · [초월] 별의 상점(transcend_panel.gd)
## · [심연] 각인(abyss_panel.gd) · [자동] 자동화 스위치(automation_panel.gd). 열리지 않은 층의 칩은 숨고, 살 것이 있는 칩엔 점. 기억의 서는 업적 탭으로 옮겼다.

const SubTabs := preload("res://scenes/tabs/sub_tabs.gd")
const MemoryPanel := preload("res://scenes/tabs/memory_panel.gd")
const RebirthPanel := preload("res://scenes/tabs/rebirth_panel.gd")
const AutomationPanel := preload("res://scenes/tabs/automation_panel.gd")
const TranscendPanel := preload("res://scenes/tabs/transcend_panel.gd")
const AbyssPanel := preload("res://scenes/tabs/abyss_panel.gd")
const MARGIN: int = 16

var tabs: SubTabs


func _ready() -> void:
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)
	tabs = SubTabs.new()
	add_child(tabs)
	tabs.add_scroll_page("회귀", [MemoryPanel.new()], Callable(), _any_buyable.bind(Balance.MEMORIES.size(), Prestige.can_buy))
	tabs.add_scroll_page("환생", [RebirthPanel.new()], _rebirth_open, _rebirth_dot)
	tabs.add_scroll_page("초월", [TranscendPanel.new()], _transcend_open, _transcend_dot)
	tabs.add_scroll_page("심연", [AbyssPanel.new()], Abyss.is_unlocked, _any_buyable.bind(Balance.MARKS.size(), Abyss.can_buy))
	tabs.add_scroll_page("자동", [AutomationPanel.new()], _automation_open)


## 첫 회귀 뒤에 다음 층(환생)이 무엇인지 보인다. 그 전에는 회귀 하나만이라 칩 줄도 숨는다
func _rebirth_open() -> bool:
	return Prestige.prestige_count > 0 or Rebirth.rebirth_count > 0 or Transcend.count > 0


func _rebirth_dot() -> bool:
	return Rebirth.can_rebirth() or _any_buyable(Balance.FATES.size(), Rebirth.can_buy)


func _transcend_open() -> bool:
	return Transcend.count > 0 or Achievements.value(Balance.Stat.FINAL) > 0.0


func _transcend_dot() -> bool:
	return Transcend.can_transcend() or _any_buyable(Balance.STARS.size(), Transcend.can_buy)


func _automation_open() -> bool:
	for kind in Balance.AUTO_NAMES.size():
		if Automation.is_unlocked(kind):
			return true
	return false


func _any_buyable(count: int, can_buy: Callable) -> bool:
	for i in count:
		if can_buy.call(i):
			return true
	return false
