extends ScrollContainer
## 손가락으로 끌어 스크롤하는 목록. 안의 버튼이 터치를 삼키면 버튼 위에서 시작한 드래그가 스크롤되지 않으므로
## (모바일 검사에서 확인), 버튼은 mouse_filter IGNORE로 두고 여기서 탭을 판정한다. 누른 자리에서
## TAP_SLOP 안에서 떼면 그 자리의 버튼을 누른 것으로 친다. 끌기 스크롤은 엔진(ScrollContainer)이 그대로 한다.
## _gui_input을 덮어쓰면 엔진의 끌기 스크롤이 사라지므로 gui_input 시그널을 쓴다.

const TAP_SLOP: float = 24.0     # 이 거리(게임 px) 안에서 떼면 탭, 넘으면 드래그
const PRESS_FLASH: float = 0.12  # 눌림 표시 시간 (초)
const PRESS_TINT := Color(0.7, 0.7, 0.7)

var _press_position: Vector2 = Vector2.INF


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gui_input.connect(_on_gui_input)


## 안의 버튼이 터치를 삼키지 않게 하고, 줄 배경(PanelContainer)이 마우스 이벤트를 막지 않게 한다.
## PanelContainer는 기본이 STOP이라 탭 판정에 쓰는 마우스 이벤트가 여기까지 오지 못한다. 줄을 다 만든 뒤 한 번 부른다
func release_buttons() -> void:
	for node in find_children("*", "Button", true, false):
		var button := node as Control
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in find_children("*", "PanelContainer", true, false):
		var panel := node as Control
		panel.mouse_filter = Control.MOUSE_FILTER_PASS


## 마우스 버튼 이벤트만 본다. 터치는 엔진이 마우스로도 흉내 내 주므로 폰과 PC를 같은 길로 처리한다
func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_position = button.global_position
		return
	var released_at := button.global_position
	if _press_position != Vector2.INF and released_at.distance_to(_press_position) <= TAP_SLOP:
		_tap(released_at)
	_press_position = Vector2.INF


## 그 자리에 보이는, 눌 수 있는 버튼이 있으면 눌린 것으로 친다
func _tap(global_point: Vector2) -> bool:
	for node in find_children("*", "Button", true, false):
		var target := node as Button
		if target.disabled or not target.is_visible_in_tree():
			continue
		if not target.get_global_rect().has_point(global_point):
			continue
		_flash(target)
		target.pressed.emit()
		return true
	return false


func _flash(target: Button) -> void:
	target.modulate = PRESS_TINT
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color.WHITE, PRESS_FLASH)
