extends HBoxContainer
## 탭 내비게이션 (GDD 9절: 용사 / 동료 / 단련 / 회귀 / 업적 / 설정). 손가락으로 누르기 좋게 폭을 똑같이 나눈 큰 버튼이다.
## 누르면 tab_selected를 내고, Main이 그 번호의 패널만 보인다. 점(badge)은 버튼 안에 붙어 있어 탭 폭이 변하지 않는다.

signal tab_selected(index: int)

const TITLES: PackedStringArray = ["용사", "동료", "단련", "회귀", "업적", "설정"]
const BADGE_SIZE := Vector2(12, 12)
const BADGE_COLOR := Color("ffe66d")
const BADGE_OFFSET := Vector2(6, 18)  # 탭 글자의 오른쪽 위에서 얼마나 떨어질지

var _buttons: Array[Button] = []
var _badges: Array[Panel] = []


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var group := ButtonGroup.new()
	for i in TITLES.size():
		var button := Button.new()
		button.text = TITLES[i]
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = "NavButton"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(tab_selected.emit.bind(i))
		add_child(button)
		_buttons.append(button)
		_badges.append(_make_badge(button))


func _make_badge(button: Button) -> Panel:
	var badge := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_COLOR
	style.set_corner_radius_all(roundi(BADGE_SIZE.x * 0.5))
	badge.add_theme_stylebox_override("panel", style)
	# 글자 오른쪽 위에 붙인다. 버튼은 글자를 가운데 놓으므로 글자 폭의 절반만큼 오른쪽으로 간다
	var font := button.get_theme_font("font")
	var text_width := font.get_string_size(
		button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
	badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	badge.position = Vector2(text_width * 0.5 + BADGE_OFFSET.x, BADGE_OFFSET.y)
	badge.size = BADGE_SIZE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	button.add_child(badge)
	return badge


func select(index: int) -> void:
	_buttons[index].button_pressed = true
	tab_selected.emit(index)


func set_badge(index: int, shown: bool) -> void:
	_badges[index].visible = shown
