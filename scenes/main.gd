extends Control
## 세로 화면 전체 (GDD 9절). 상단 바, 전투 화면, 탭 패널을 위에서부터 쌓는다.
## 스킬 바는 M4에서 전투 화면과 탭 패널 사이에 들어간다.

const TAB_TITLES: PackedStringArray = ["용사", "동료", "회귀", "설정"]
## 아직 내용이 없는 탭에 보여줄 안내. 마일스톤이 끝나면 지운다
const TAB_PLACEHOLDERS: Dictionary = {
	"PrestigeTab": "회귀는 M5에서 열립니다",
	"SettingsTab": "설정은 M3에서 추가됩니다",
}

@onready var _tabs: TabContainer = $Layout/Tabs


func _ready() -> void:
	for i in TAB_TITLES.size():
		_tabs.set_tab_title(i, TAB_TITLES[i])
	for tab_name: String in TAB_PLACEHOLDERS:
		var label := Label.new()
		label.text = TAB_PLACEHOLDERS[tab_name]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tabs.get_node(tab_name).add_child(label)
