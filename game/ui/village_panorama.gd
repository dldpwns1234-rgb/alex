class_name VillagePanorama
extends ScrollContainer

## 마을 전경 (ARCHITECTURE §6.3).
##
## 타일맵이 아니다 (GDD D13). 고정 좌표에 놓인 슬롯의 집합이다.
## 슬롯 좌표는 data/village_layout.json이 갖고 있고, sim은 그 파일에서
## unlock_year만 읽어간다. 여기는 x/y만 읽는다.
##
## **슬롯이 Button이 아닌 이유 — 드래그 스크롤.**
## Button은 터치를 소비한다. 슬롯 위에서 손가락을 끌면 그 이벤트가
## ScrollContainer까지 오지 않아 화면이 스크롤되지 않는다.
## 슬롯이 화면의 대부분을 덮고 있으므로, 사실상 스크롤이 불가능해진다.
##
## 그래서 슬롯은 입력을 받지 않는 Panel로 두고(mouse_filter = IGNORE),
## **탭 판정을 이 클래스가 직접 한다.** 누른 지점에서 조금이라도 끌렸으면
## 스크롤로, 제자리에서 뗐으면 탭으로 해석한다.
##
## **건물을 지으면 마을 그림이 눈에 띄게 변한다** — 이것이 진행감의 핵심 보상이므로
## (GDD §4.6) 슬롯 외형은 상태별로 확실히 다르게 그린다.
##
## TODO(M5): 슬롯 패널을 실제 건물 스프라이트로 교체한다.
##           계절 색조는 셰이더 오버레이 1장으로 처리한다 (ARCHITECTURE §6.3).

signal slot_pressed(slot_index: int)

const SLOT_SIZE := Vector2(264, 112)
const SLOT_FONT_SIZE := 22

## 이 거리를 넘겨 끌었으면 탭이 아니라 스크롤이다.
## 너무 작으면 손가락이 미세하게 흔들렸을 때 스크롤이 탭으로 오인되고,
## 너무 크면 짧게 밀었을 때 엉뚱한 건물 화면이 열린다.
const TAP_SLOP := 24.0

## 슬롯 상태별 색. 도트 아트가 들어오기 전까지의 자리표시자다.
const COLOR_LOCKED := Color(0.10, 0.11, 0.13, 0.55)
const COLOR_EMPTY := Color(0.16, 0.18, 0.20, 0.85)
const COLOR_BUILDING := Color(0.42, 0.34, 0.18, 0.95)
const COLOR_ACTIVE := Color(0.30, 0.36, 0.28, 1.0)
## 멈춘 건물. 파노라마를 훑기만 해도 눈에 띄어야 한다.
const COLOR_HALTED := Color(0.45, 0.26, 0.20, 1.0)
const COLOR_PATH := Color(0, 0, 0, 0.18)

var _canvas: Control
## 슬롯별 { panel, label, rect, tappable }
var _slots: Array[Dictionary] = []

var _pressing := false
var _press_position := Vector2.ZERO


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# 폰에서 손가락으로 끌 때의 미세한 흔들림을 스크롤로 오해하지 않게 한다.
	scroll_deadzone = 12

	# `_gui_input()`을 재정의하지 않고 **시그널**에 붙는다.
	# 재정의하면 ScrollContainer가 C++에서 구현한 스크롤 처리를 덮어쓰게 되고,
	# GDScript에서는 super로 되돌릴 수도 없다 (부모가 GDScript가 아니므로).
	# 시그널은 내장 처리와 나란히 불리므로 스크롤을 잃지 않는다.
	gui_input.connect(_on_gui_input)


func build(layout: Dictionary, slot_count: int) -> void:
	var size_data: Dictionary = layout.get("panorama_size", {})
	var panorama_size := Vector2(
		float(size_data.get("width", 720)),
		float(size_data.get("height", 1080)),
	)

	_canvas = Control.new()
	_canvas.custom_minimum_size = panorama_size
	# 캔버스도 입력을 받지 않는다. 모든 입력은 ScrollContainer가 처리한다.
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	_add_path(panorama_size)

	var slots: Array = layout.get("slots", [])
	for slot_index in slot_count:
		var position := Vector2(30.0, 132.0 * slot_index)
		if slot_index < slots.size():
			position = Vector2(
				float(slots[slot_index].get("x", 0)),
				float(slots[slot_index].get("y", 0)),
			)
		_add_slot(position)


## 마을을 관통하는 길. 슬롯이 허공에 떠 있어 보이지 않게 하는 최소한의 장치다.
func _add_path(panorama_size: Vector2) -> void:
	var path := ColorRect.new()
	path.color = COLOR_PATH
	path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	path.position = Vector2(panorama_size.x * 0.5 - 24.0, 0)
	path.size = Vector2(48, panorama_size.y)
	_canvas.add_child(path)


func _add_slot(slot_position: Vector2) -> void:
	var panel := Panel.new()
	panel.position = slot_position
	panel.size = SLOT_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(panel)

	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", SLOT_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	_slots.append({
		"panel": panel,
		"label": label,
		"rect": Rect2(slot_position, SLOT_SIZE),
		"tappable": false,
	})


# --- 입력 --------------------------------------------------------------------

## 끌었으면 스크롤, 제자리에서 뗐으면 탭.
##
## 스크롤 자체는 ScrollContainer의 내장 처리가 맡는다. 여기서는 탭만 가려낸다.
func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var button := event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT:
		return

	if button.pressed:
		_pressing = true
		_press_position = button.position
		return

	if not _pressing:
		return
	_pressing = false

	if button.position.distance_to(_press_position) <= TAP_SLOP:
		_tap_at(button.position)


## 화면 좌표를 파노라마 좌표로 옮겨 어느 슬롯인지 찾는다.
func _tap_at(local_position: Vector2) -> void:
	var canvas_position := local_position + Vector2(scroll_horizontal, scroll_vertical)
	for slot_index in _slots.size():
		var slot: Dictionary = _slots[slot_index]
		if slot["tappable"] and slot["rect"].has_point(canvas_position):
			slot_pressed.emit(slot_index)
			return


# --- 상태 반영 ---------------------------------------------------------------

## 마을 상태를 화면에 반영한다. 커맨드가 성공했거나 하루가 지날 때 불린다.
func refresh(village: SimVillage) -> void:
	for slot_index in _slots.size():
		_refresh_slot(_slots[slot_index], village, slot_index)


func _refresh_slot(slot: Dictionary, village: SimVillage, slot_index: int) -> void:
	var label: Label = slot["label"]

	if not village.is_slot_unlocked(slot_index):
		_style(slot, COLOR_LOCKED)
		label.text = "잠김 · %d년차" % village.slot_unlock_years[slot_index]
		label.modulate = Color(1, 1, 1, 0.45)
		slot["tappable"] = false
		return

	slot["tappable"] = true
	label.modulate = Color(1, 1, 1, 1)

	var building := village.building_at(slot_index)
	if building == null:
		_style(slot, COLOR_EMPTY)
		label.text = "+ 빈 자리"
		return

	var building_name := BuildingDisplay.name_of(building.type_id)

	if not building.is_complete():
		_style(slot, COLOR_BUILDING)
		# 남은 일수를 그대로 보여준다. 진행 바보다 "며칠 남았나"가 판단에 쓰인다.
		label.text = "%s\n건설 중 · %d일" % [building_name, building.days_remaining]
		return

	if building.is_halted():
		_style(slot, COLOR_HALTED)
		label.text = "%s\n⚠ %s" % [building_name, BuildingDisplay.halt_badge(building.halt_reason)]
		return

	_style(slot, COLOR_ACTIVE)

	var capacity := village.worker_capacity(slot_index)
	if capacity <= 0:
		label.text = building_name
	else:
		label.text = "%s\n인력 %d / %d" % [
			building_name, village.labor.assigned_to(slot_index), capacity]


func _style(slot: Dictionary, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.15)
	slot["panel"].add_theme_stylebox_override("panel", style)
