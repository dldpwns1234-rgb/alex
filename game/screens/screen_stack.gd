class_name ScreenStack
extends Control

## 화면 스택 (ARCHITECTURE §6.1).
##
## 홈 화면 ↔ 건물 화면 ↔ 전투 화면 전환을 관리한다.
## 안드로이드 뒤로가기 버튼이 pop으로 연결되는 지점이기도 하다.
##
## 규칙:
##   1. 화면은 스택으로 관리한다. 뒤로가기 = pop
##   2. 최하단(홈) 화면은 pop되지 않는다
##   3. 어느 화면에 있든 게임 시계는 계속 돈다 — 화면 전환은 시간을 멈추지 않는다

signal depth_changed(depth: int)


func push_screen(screen: Control) -> void:
	if get_child_count() > 0:
		_top().visible = false

	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	depth_changed.emit(depth())


## 최상단 화면을 닫는다. 홈 화면만 남아 있으면 아무것도 하지 않고 false를 반환한다.
func pop_screen() -> bool:
	if get_child_count() <= 1:
		return false

	var top := _top()
	remove_child(top)
	top.queue_free()

	_top().visible = true
	depth_changed.emit(depth())
	return true


func depth() -> int:
	return get_child_count()


func _top() -> Control:
	return get_child(get_child_count() - 1) as Control


## 안드로이드 뒤로가기 버튼.
##
## project.godot의 `application/config/quit_on_go_back=false` 덕분에
## 엔진이 앱을 종료하지 않고 이 알림이 여기까지 온다.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return

	if not pop_screen():
		# 홈 화면에서 뒤로가기를 눌렀다.
		# TODO(M8): 종료 확인 다이얼로그. M0에서는 무시한다.
		pass
