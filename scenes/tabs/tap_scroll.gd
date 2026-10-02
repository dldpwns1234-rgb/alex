extends ScrollContainer
## 손가락으로 끌어 스크롤하는 목록. 안의 버튼이 터치를 삼키면 버튼 위에서 시작한 드래그가 스크롤되지 않으므로
## (모바일 검사에서 확인), 버튼은 mouse_filter IGNORE로 두고 여기서 탭을 판정한다. 누른 자리에서
## TAP_SLOP 안에서 떼면 그 자리의 버튼을 누른 것으로 친다.
## 끌기 스크롤도 여기서 한다: 엔진의 끌기는 폰에서 화면이 손가락보다 조금 더 빨리 움직였다 (방장 2026-10-02).
## 누른 자리와 지금 자리(게임 좌표)의 차이만큼 정확히 옮기고, 놓으면 마지막 속도로 짧게 미끄러지다 멈춘다.
## gui_input 시그널은 엔진의 _gui_input보다 먼저 와서, 움직임을 accept_event로 막으면 엔진의 끌기·관성이 끼지 않는다.

const TAP_SLOP: float = 24.0     # 이 거리(게임 px) 안에서 떼면 탭, 넘으면 드래그
const PRESS_FLASH: float = 0.12  # 눌림 표시 시간 (초)
const PRESS_TINT := Color(0.7, 0.7, 0.7)
const FLING_FRICTION: float = 6.0     # 놓은 뒤 미끄러짐이 줄어드는 빠르기 (초당, 클수록 빨리 멈춘다)
const FLING_MIN_SPEED: float = 30.0   # 이보다 느리면 (게임 px/초) 멈춘다
const SPEED_SMOOTHING: float = 0.3    # 손가락 속도 재기: 새 값의 비중

var _press_position: Vector2 = Vector2.INF
var _press_scroll: float = 0.0
var _dragging: bool = false
var _last_y: float = 0.0
var _last_msec: int = 0
var _speed: float = 0.0   # 손가락 속도 (게임 px/초, 아래로 +)
var _fling: float = 0.0   # 놓은 뒤 남은 스크롤 속도


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gui_input.connect(_on_gui_input)


## 안의 버튼이 터치를 삼키지 않게 하고, 줄 배경(PanelContainer)이 마우스 이벤트를 막지 않게 한다.
## PanelContainer는 기본이 STOP이라 탭 판정에 쓰는 마우스 이벤트가 여기까지 오지 못한다. 줄을 다 만든 뒤 한 번 부른다.
## 확인 창(Window) 안의 버튼은 창이 직접 입력을 받으므로 건드리지 않는다 (건드리면 창의 버튼이 안 눌린다)
func release_buttons() -> void:
	for node in find_children("*", "Button", true, false):
		var button := node as Control
		if _in_own_window(button):
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in find_children("*", "PanelContainer", true, false):
		var panel := node as Control
		if _in_own_window(panel):
			panel.mouse_filter = Control.MOUSE_FILTER_PASS


## 이 목록과 같은 창에 있는지 (확인 창 같은 자식 Window 안이 아닌지)
func _in_own_window(control: Control) -> bool:
	return control.get_window() == get_window()


## 마우스 이벤트만 본다. 터치는 엔진이 마우스로도 흉내 내 주므로 폰과 PC를 같은 길로 처리한다 (휠은 엔진이 그대로)
func _on_gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and _press_position != Vector2.INF:
		_drag(motion.global_position.y)
		accept_event()
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_position = button.global_position
		_press_scroll = scroll_vertical
		_dragging = false
		_fling = 0.0
		_speed = 0.0
		_last_y = button.global_position.y
		_last_msec = Time.get_ticks_msec()
		return
	var released_at := button.global_position
	if _press_position != Vector2.INF and not _dragging and released_at.distance_to(_press_position) <= TAP_SLOP:
		_tap(released_at)
	elif _dragging:
		_fling = -_speed
	_press_position = Vector2.INF
	_dragging = false  # 뗌은 막지 않는다: 엔진이 누름으로 시작한 끌기 상태를 끝내야 한다 (움직임을 못 봐서 관성은 없다)


## 누른 자리에서 손가락이 움직인 만큼 정확히 옮긴다. TAP_SLOP을 넘기 전에는 탭일 수 있어 움직이지 않는다
func _drag(y: float) -> void:
	if not _dragging and absf(y - _press_position.y) <= TAP_SLOP:
		return
	_dragging = true
	scroll_vertical = roundi(_press_scroll - (y - _press_position.y))
	var now := Time.get_ticks_msec()
	var dt := maxf((now - _last_msec) / 1000.0, 0.001)
	_speed = lerpf(_speed, (y - _last_y) / dt, SPEED_SMOOTHING)
	_last_y = y
	_last_msec = now


## 놓은 뒤 미끄러짐: 마지막 손가락 속도에서 지수로 줄어든다
func _process(delta: float) -> void:
	if absf(_fling) < FLING_MIN_SPEED:
		_fling = 0.0
		return
	var before := scroll_vertical
	scroll_vertical = roundi(scroll_vertical + _fling * delta)
	if scroll_vertical == before and absf(_fling * delta) >= 1.0:
		_fling = 0.0  # 끝에 닿았다
		return
	_fling *= exp(-FLING_FRICTION * delta)


## 그 자리에 보이는, 눌 수 있는 버튼이 있으면 눌린 것으로 친다
func _tap(global_point: Vector2) -> bool:
	for node in find_children("*", "Button", true, false):
		var target := node as Button
		if target.disabled or not target.is_visible_in_tree() or not _in_own_window(target):
			continue
		if not target.get_global_rect().has_point(global_point):
			continue
		_flash(target)
		if target.toggle_mode:
			target.button_pressed = not target.button_pressed  # toggled 시그널이 난다
		else:
			target.pressed.emit()
		return true
	return false


func _flash(target: Button) -> void:
	target.modulate = PRESS_TINT
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color.WHITE, PRESS_FLASH)
