extends "res://tests/test_case.gd"
## 목록의 탭 판정: 24px 안에서 떼면 탭, 넘으면 드래그. 버튼은 터치를 삼키지 않는다

const TapScroll := preload("res://scenes/tabs/tap_scroll.gd")

var _presses: int = 0


func run() -> void:
	await _test_tap()
	_test_dialog_buttons()


## 목록 안에 둔 확인 창의 버튼은 창이 직접 입력을 받아야 하므로 건드리지 않는다 (환생 확인 창이 안 눌리던 버그)
func _test_dialog_buttons() -> void:
	var scroll: ScrollContainer = TapScroll.new()
	add_child(scroll)
	var holder := VBoxContainer.new()
	scroll.add_child(holder)
	var button := Button.new()
	holder.add_child(button)
	var dialog := ConfirmationDialog.new()
	holder.add_child(dialog)
	scroll.release_buttons()
	_equal(button.mouse_filter, Control.MOUSE_FILTER_IGNORE, "목록의 버튼은 입력을 무시한다")
	_equal(dialog.get_ok_button().mouse_filter, Control.MOUSE_FILTER_STOP, "확인 창의 버튼은 그대로 눌린다")
	scroll.queue_free()


func _on_pressed() -> void:
	_presses += 1


func _mouse(pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = at
	event.position = at
	return event


func _test_tap() -> void:
	var scroll: ScrollContainer = TapScroll.new()
	scroll.size = Vector2(400, 300)
	add_child(scroll)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 600)
	scroll.add_child(panel)
	var holder := Control.new()
	panel.add_child(holder)
	var button := Button.new()
	button.position = Vector2(200, 100)
	button.size = Vector2(150, 60)
	button.pressed.connect(_on_pressed)
	holder.add_child(button)
	_equal(panel.mouse_filter, Control.MOUSE_FILTER_STOP, "줄 패널은 기본이 STOP이라 마우스를 막는다")
	scroll.release_buttons()
	await get_tree().process_frame
	_equal(button.mouse_filter, Control.MOUSE_FILTER_IGNORE, "버튼은 터치를 삼키지 않는다")
	_equal(panel.mouse_filter, Control.MOUSE_FILTER_PASS, "줄 패널은 마우스를 통과시킨다")

	var inside := button.get_global_rect().get_center()
	scroll._on_gui_input(_mouse(true, inside))
	scroll._on_gui_input(_mouse(false, inside + Vector2(10, 10)))
	_equal(_presses, 1, "누르고 24px 안에서 떼면 버튼이 눌린다")

	scroll._on_gui_input(_mouse(true, inside))
	scroll._on_gui_input(_mouse(false, inside + Vector2(0, 80)))
	_equal(_presses, 1, "멀리 끌고 떼면 드래그라 눌리지 않는다")

	var outside := button.get_global_rect().position - Vector2(20, 20)
	scroll._on_gui_input(_mouse(true, outside))
	scroll._on_gui_input(_mouse(false, outside))
	_equal(_presses, 1, "버튼 밖을 탭하면 아무 일도 없다")

	button.disabled = true
	scroll._on_gui_input(_mouse(true, inside))
	scroll._on_gui_input(_mouse(false, inside))
	_equal(_presses, 1, "비활성 버튼은 눌리지 않는다")

	scroll._on_gui_input(_mouse(false, inside))
	_equal(_presses, 1, "누른 적 없이 떼기만 하면 무시")
	scroll.queue_free()
