class_name BuildingScreen
extends Control

## 건물 화면의 공통 골격 (ARCHITECTURE §6.2).
##
## 건물은 10~12종까지 늘어난다 (GDD §4.5). 종마다 화면을 처음부터 그리면
## 감당할 수 없으므로, **서브클래스가 채우는 곳은 고유 영역 하나뿐**이다.
## 새 건물의 비용을 "화면 하나"에서 "패널 하나"로 낮추는 것이 이 클래스의 목적이다.
##
## M1에서는 골격만 세운다. 실제 의사결정(GDD §4.6)은 M2부터 고유 영역에 들어간다.

const MIN_TOUCH_PX := 96

var slot_index: int
var type_id: String

var _state_label: Label


func _init(building_slot_index: int, building_type_id: String) -> void:
	slot_index = building_slot_index
	type_id = building_type_id


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	Game.world.day_advanced.connect(_on_day_advanced)
	_refresh_state()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.09, 0.10, 0.12, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_unique_area())
	column.add_child(_build_footer())


func _build_header() -> Control:
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = BuildingDisplay.name_of(type_id)
	title.add_theme_font_size_override("font_size", 48)
	header.add_child(title)

	var description := Label.new()
	description.text = BuildingDisplay.description_of(type_id)
	description.modulate = Color(1, 1, 1, 0.55)
	header.add_child(description)

	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 26)
	header.add_child(_state_label)

	return header


## 서브클래스가 재정의하는 **유일한** 부분이다.
##
## 여기에 들어갈 것 (GDD §4.6):
##   농장   — 작물 선택, 파종 시기, 휴경 여부
##   대장간 — 제작 큐, 마정석 부여 여부
##   창고   — 배급 정책
##   교역소 — 시세, 교역대 편성, 호위 배정
func _build_unique_area() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	panel.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)

	# TODO(M2): 인력 배정 슬라이더. 모든 건물 화면의 공통 요소이므로
	#           베이스 클래스가 제공해야 한다 (GDD §4.6 설계 규칙).
	var placeholder := Label.new()
	placeholder.text = "인력 배정 · 생산 큐 · 정책은 M2에서 구현됩니다"
	placeholder.modulate = Color(1, 1, 1, 0.45)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(placeholder)

	var workers := Game.world.village.catalog.get_type(type_id)
	if workers != null and workers.workers > 0:
		var worker_label := Label.new()
		worker_label.text = "필요 인력 %d명" % workers.workers
		worker_label.modulate = Color(1, 1, 1, 0.7)
		worker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(worker_label)

	return panel


func _build_footer() -> Control:
	# TODO(M8): 업그레이드 · 철거 버튼 (ARCHITECTURE §6.2).
	var back := Button.new()
	back.text = "뒤로"
	back.custom_minimum_size = Vector2(0, MIN_TOUCH_PX)
	back.pressed.connect(_on_back_pressed)
	return back


func _on_day_advanced(_elapsed_days: int) -> void:
	# 건물 화면에 들어와 있어도 시계는 계속 돈다 (ARCHITECTURE §6.1 규칙 3).
	_refresh_state()


func _refresh_state() -> void:
	var building := Game.world.village.building_at(slot_index)
	var date := SeasonDisplay.format_date(Game.world.calendar)

	if building == null:
		_state_label.text = date
	elif building.is_complete():
		_state_label.text = "가동 중 · %s" % date
	else:
		_state_label.text = "건설 중 · %d일 남음 · %s" % [building.days_remaining, date]


func _on_back_pressed() -> void:
	var stack := get_parent() as ScreenStack
	if stack != null:
		stack.pop_screen()
