class_name StubBuildingScreen
extends Control

## 건물 화면 자리표시자.
##
## M0의 목적은 두 가지를 실증하는 것이다:
##   1. 화면 스택 push/pop이 동작한다 — 안드로이드 뒤로가기 버튼 포함
##   2. 화면을 전환해도 게임 시계가 멈추지 않는다 (ARCHITECTURE §6.1 규칙 3)
##
## M1~M2에서 BuildingScreen 베이스 클래스(ARCHITECTURE §6.2)로 대체된다.

var _date_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	Game.world.day_advanced.connect(func(_days: int) -> void: _refresh_date())
	_refresh_date()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.10, 0.10, 0.13)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	var title := Label.new()
	title.text = "건물 화면"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var note := Label.new()
	note.text = "인력 배정 · 생산 큐 · 정책은 M2에서 구현됩니다"
	note.modulate = Color(1, 1, 1, 0.5)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)

	# 이 화면에서도 날짜가 계속 흐르는 것을 보여준다.
	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 36)
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_date_label)

	var hint := Label.new()
	hint.text = "안드로이드 뒤로가기 버튼으로도 닫힙니다"
	hint.modulate = Color(1, 1, 1, 0.4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	var back := Button.new()
	back.text = "뒤로"
	back.custom_minimum_size = Vector2(0, HomeScreen.MIN_TOUCH_PX)
	back.pressed.connect(_on_back_pressed)
	column.add_child(back)


func _refresh_date() -> void:
	_date_label.text = SeasonDisplay.format_date(Game.world.calendar)


func _on_back_pressed() -> void:
	var stack := get_parent() as ScreenStack
	if stack != null:
		stack.pop_screen()
