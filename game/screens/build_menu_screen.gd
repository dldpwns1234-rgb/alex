class_name BuildMenuScreen
extends Control

## 건물 선택 메뉴 — 빈 슬롯을 탭했을 때 뜬다 (GDD §4.5).
##
## 팝업이 아니라 스택에 올라가는 화면이다. 그래야 안드로이드 뒤로가기가
## 별도 처리 없이 그대로 "닫기"가 된다 (ARCHITECTURE §6.1).
##
## 잠긴 건물도 **목록에서 감추지 않는다.** 무엇이 앞에 있는지 보여야
## 해금 사슬(GDD §4.5)이 목표로 기능한다.

signal building_chosen(slot_index: int, type_id: String)

const MIN_TOUCH_PX := 96

var _slot_index: int
var _village: SimVillage


func _init(slot_index: int, village: SimVillage) -> void:
	_slot_index = slot_index
	_village = village


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.10, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_building_list())
	column.add_child(_build_close_button())


func _build_header() -> Control:
	var header := HBoxContainer.new()

	var title := Label.new()
	title.text = "%d번 자리에 무엇을 지을까" % (_slot_index + 1)
	title.add_theme_font_size_override("font_size", 40)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	header.add_child(_build_resource_summary())
	return header


func _build_resource_summary() -> Control:
	var label := Label.new()
	label.text = ResourceDisplay.format_stock(_village.resources, " · ")
	label.modulate = Color(1, 1, 1, 0.75)
	return label


func _build_building_list() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var completed := _village.completed_type_ids()
	for type_id in _village.catalog.ids():
		list.add_child(_build_entry(type_id, completed))

	return scroll


func _build_entry(type_id: String, completed: Dictionary) -> Control:
	var type := _village.catalog.get_type(type_id)
	var missing := _village.catalog.missing_requirements(type_id, completed)
	var is_locked := not missing.is_empty()
	var can_afford := _village.resources.can_afford(type.cost)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, MIN_TOUCH_PX + 24)
	button.disabled = is_locked or not can_afford
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: building_chosen.emit(_slot_index, type_id))

	# Button 위에 라벨을 얹어 2단 구성을 만든다. 텍스트 한 줄로는
	# 이름 · 비용 · 거절 사유를 동시에 보여줄 수 없다.
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		row.add_theme_constant_override("margin_" + side, 20)
	button.add_child(row)

	var name_column := VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_column.alignment = BoxContainer.ALIGNMENT_CENTER
	name_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_column)

	var name_label := Label.new()
	name_label.text = "  %s" % BuildingDisplay.name_of(type_id)
	name_label.add_theme_font_size_override("font_size", 30)
	name_column.add_child(name_label)

	var detail := Label.new()
	detail.text = "  %s · %d일" % [BuildingDisplay.format_cost(type.cost), type.build_days]
	detail.add_theme_font_size_override("font_size", 22)
	detail.modulate = Color(1, 1, 1, 0.6)
	name_column.add_child(detail)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 24)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_locked:
		status.text = "%s 필요  " % BuildingDisplay.requirement_list(missing)
		status.modulate = Color(1, 0.85, 0.5, 0.8)
	elif not can_afford:
		status.text = "자원 부족  "
		status.modulate = Color(1, 0.6, 0.6, 0.9)
	else:
		status.text = "건설  "
		status.modulate = Color(0.7, 1.0, 0.7, 0.95)
	row.add_child(status)

	return button


func _build_close_button() -> Control:
	var button := Button.new()
	button.text = "닫기"
	button.custom_minimum_size = Vector2(0, MIN_TOUCH_PX)
	button.pressed.connect(_close)
	return button


func _close() -> void:
	var stack := get_parent() as ScreenStack
	if stack != null:
		stack.pop_screen()
