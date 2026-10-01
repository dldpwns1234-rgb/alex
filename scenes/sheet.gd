extends PanelContainer
## 하단 메뉴 시트 (GDD 9절): 스킬 바, 구매 배수, 탭, 패널을 담고 화면 아래에 붙어 있다. 늘리고 줄일 수 있다.
## 접히면 Layout이 비워 둔 자리(SheetSpace)에 꼭 맞고, 펼치면 전투 화면 위로 올라와 패널이 그만큼 커진다 (동료 4명이 한 번에 보인다).
## 구매 배수 줄 왼쪽의 손잡이 버튼: 누르면 접힘 ↔ 상단 바 아래까지 펼침, 끌면 그 높이에 멈춘다 (접힌 높이 근처면 접는다).
## 높이는 Prefs가 들고 저장된다. 여기서는 Prefs.set_sheet_height()를 부르고 sheet_height_changed를 받아 움직인다.

signal height_changed(height: float)

const HANDLE_WIDTH: float = 150.0
const DRAG_SLOP: float = 12.0       # 이만큼 움직이면 탭이 아니라 끌기 (게임 px)
const COLLAPSE_SNAP: float = 24.0   # 접힌 높이에서 이 안에 놓으면 접는다
const SLIDE_DURATION: float = 0.2
const EXPAND_TEXT: String = "▲ 펼치기"
const COLLAPSE_TEXT: String = "▼ 접기"

@onready var _column: VBoxContainer = $Column
@onready var _buy_bar: HBoxContainer = $Column/BuyBar

var _top_inset: float = 0.0  # 펼쳐도 남겨 두는 위쪽 높이 (상단 바). Main이 정한다
var _handle: Button
var _height: float = 0.0
var _press_y: float = INF
var _press_height: float = 0.0
var _dragged: bool = false
var _tween: Tween


func _ready() -> void:
	theme_type_variation = "Sheet"
	_handle = Button.new()
	_handle.custom_minimum_size = Vector2(HANDLE_WIDTH, 0.0)
	_handle.gui_input.connect(_on_handle_input)
	_handle.pressed.connect(_on_handle_pressed)
	_buy_bar.add_child(_handle)
	_buy_bar.move_child(_handle, 0)
	Prefs.sheet_height_changed.connect(_on_pref_changed)
	get_parent().resized.connect(_on_parent_resized)
	_apply(Prefs.sheet_height, false)


## 접힌 높이: 씬에 적은 높이의 합 (스킬 바 + 구매 배수 + 탭 + 패널 440) + 시트 스타일의 위쪽 선.
## 실제 최소 크기(get_combined_minimum_size)는 보이는 탭의 내용에 따라 변하고 시작할 때는 탭이 다 보여서 쓰지 않는다
func collapsed_height() -> float:
	var total := get_theme_stylebox("panel").get_minimum_size().y
	for child in _column.get_children():
		total += (child as Control).custom_minimum_size.y
	return total


## 끝까지 펼친 높이: 화면 높이에서 상단 바를 뺀 것
func max_height() -> float:
	var parent := get_parent() as Control
	return maxf(parent.size.y - _top_inset, collapsed_height())


func current_height() -> float:
	return _height


func is_expanded() -> bool:
	return _height > collapsed_height() + COLLAPSE_SNAP


func set_top_inset(inset: float) -> void:
	_top_inset = inset
	_apply(Prefs.sheet_height, false)


func _on_pref_changed(height: float) -> void:
	_apply(height, true)


func _on_parent_resized() -> void:
	_apply(Prefs.sheet_height, false)


## 0이면 접힌 높이, 아니면 접힌 높이와 최대 사이로 자른다
func _resolve(height: float) -> float:
	if height <= 0.0:
		return collapsed_height()
	return clampf(height, collapsed_height(), max_height())


func _apply(height: float, animate: bool) -> void:
	var target := _resolve(height)
	if _tween != null:
		_tween.kill()
	if animate and not is_equal_approx(target, _height):
		_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_method(_set_height, _height, target, SLIDE_DURATION)
	else:
		_set_height(target)


func _set_height(height: float) -> void:
	_height = height
	offset_top = -height
	_handle.text = COLLAPSE_TEXT if is_expanded() else EXPAND_TEXT
	height_changed.emit(height)


## 손잡이를 끌지 않고 눌렀으면 접힘과 끝까지 펼침을 오간다
func _on_handle_pressed() -> void:
	if _dragged:
		return
	Prefs.set_sheet_height(0.0 if is_expanded() else max_height())


## 손잡이 끌기. 마우스 이벤트만 본다 (터치는 엔진이 마우스로도 흉내 낸다). 누른 채 움직이면 높이가 따라오고, 떼면 그 높이를 저장한다.
## gui_input 시그널은 버튼 자신의 처리보다 먼저 오므로 떼는 순간의 끌기 여부를 pressed에서 볼 수 있다
func _on_handle_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press_y = button.global_position.y
			_press_height = _height
			_dragged = false
		elif _press_y != INF:
			_press_y = INF
			if _dragged:
				_commit()
		return
	var motion := event as InputEventMouseMotion
	if motion == null or _press_y == INF:
		return
	var lift := _press_y - motion.global_position.y
	if not _dragged and absf(lift) < DRAG_SLOP:
		return
	_dragged = true
	_apply(_press_height + lift, false)


## 끌기를 마치면 높이를 저장한다. 접힌 높이 근처면 접힌 것으로 (저장값 0)
func _commit() -> void:
	var height := _height if is_expanded() else 0.0
	if is_equal_approx(height, Prefs.sheet_height):
		_apply(height, true)  # 저장값이 그대로면 시그널이 없으므로 직접 제자리로
	else:
		Prefs.set_sheet_height(height)
