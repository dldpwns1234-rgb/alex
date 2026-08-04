class_name HomeScreen
extends Control

## 홈 화면 — 마을 전경 (GDD §4.6).
##
## M0에서는 시계가 돌아가는 것만 보여준다.
## M1에서 마을 파노라마 · 건물 슬롯 · 자원 바가 여기에 붙는다.

## 터치 타겟 최소 크기.
##
## 뷰포트 세로 720px가 폰 세로 약 360dp에 대응하므로 1dp ≈ 2px이다.
## 안드로이드 접근성 가이드라인의 48dp는 여기서 96px이 된다
## (ARCHITECTURE §12.2).
const MIN_TOUCH_PX := 96

var _background: ColorRect
var _date_label: Label
var _speed_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	Game.world.day_advanced.connect(_on_day_advanced)
	Game.world.season_changed.connect(_on_season_changed)
	Game.speed_changed.connect(_on_speed_changed)

	_refresh_date()
	_refresh_season()
	_on_speed_changed(Game.speed_index)


# --- UI 구성 -----------------------------------------------------------------

func _build_ui() -> void:
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	column.add_child(_build_top_bar())
	column.add_child(_build_village_view())
	column.add_child(_build_speed_bar())


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()

	var resources := Label.new()
	resources.text = "자원 — M1에서 구현"
	resources.modulate = Color(1, 1, 1, 0.5)
	bar.add_child(resources)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 40)
	bar.add_child(_date_label)

	return bar


func _build_village_view() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	panel.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	var title := Label.new()
	title.text = "마을 전경"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var note := Label.new()
	note.text = "건물 슬롯과 파노라마는 M1에서 구현됩니다"
	note.modulate = Color(1, 1, 1, 0.5)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)

	# 화면 스택과 안드로이드 뒤로가기를 실제로 검증하기 위한 임시 버튼.
	# M1에서 실제 건물 탭으로 대체된다.
	var open_building := Button.new()
	open_building.text = "건물 화면 열기 (스택 테스트)"
	open_building.custom_minimum_size = Vector2(0, MIN_TOUCH_PX)
	open_building.pressed.connect(_on_open_building_pressed)
	column.add_child(open_building)

	return panel


func _build_speed_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)

	var group := ButtonGroup.new()
	for index in Game.SPEEDS.size():
		var button := Button.new()
		button.text = Game.SPEED_LABELS[index]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(MIN_TOUCH_PX * 1.5, MIN_TOUCH_PX)
		button.pressed.connect(Game.set_speed.bind(index))
		bar.add_child(button)
		_speed_buttons.append(button)

	return bar


# --- 상태 반영 ---------------------------------------------------------------

func _on_day_advanced(_elapsed_days: int) -> void:
	_refresh_date()


func _on_season_changed(_season: SimCalendar.Season) -> void:
	_refresh_season()


func _on_speed_changed(index: int) -> void:
	if index < _speed_buttons.size():
		_speed_buttons[index].button_pressed = true


func _refresh_date() -> void:
	_date_label.text = SeasonDisplay.format_date(Game.world.calendar)


func _refresh_season() -> void:
	_background.color = SeasonDisplay.color_of(Game.world.calendar.season())


func _on_open_building_pressed() -> void:
	var stack := get_parent() as ScreenStack
	if stack == null:
		return
	stack.push_screen(StubBuildingScreen.new())
