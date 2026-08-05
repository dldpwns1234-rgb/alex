class_name VillagePanorama
extends ScrollContainer

## 마을 전경 — 가로 스크롤 파노라마 (ARCHITECTURE §6.3).
##
## 타일맵이 아니다 (GDD D13). 고정 좌표에 놓인 슬롯 버튼의 집합이다.
## 슬롯 좌표는 data/village_layout.json이 갖고 있고, sim은 그 파일에서
## unlock_year만 읽어간다. 여기는 x/y만 읽는다.
##
## **건물을 지으면 마을 그림이 눈에 띄게 변한다** — 이것이 진행감의 핵심 보상이므로
## (GDD §4.6) 슬롯 외형은 상태별로 확실히 다르게 그린다.
##
## TODO(M5): 슬롯 버튼을 실제 건물 스프라이트로 교체한다.
##           계절 색조는 셰이더 오버레이 1장으로 처리한다 (ARCHITECTURE §6.3).

signal slot_pressed(slot_index: int)

const SLOT_SIZE := Vector2(210, 132)

## 슬롯 상태별 색. 도트 아트가 들어오기 전까지의 자리표시자다.
const COLOR_LOCKED := Color(0.10, 0.11, 0.13, 0.55)
const COLOR_EMPTY := Color(0.16, 0.18, 0.20, 0.85)
const COLOR_BUILDING := Color(0.42, 0.34, 0.18, 0.95)
const COLOR_ACTIVE := Color(0.30, 0.36, 0.28, 1.0)
## 멈춘 건물. 파노라마를 훑기만 해도 눈에 띄어야 한다.
const COLOR_HALTED := Color(0.45, 0.26, 0.20, 1.0)
const COLOR_GROUND := Color(0, 0, 0, 0.22)

var _canvas: Control
var _slot_buttons: Array[Button] = []


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# 폰에서 손가락으로 끌어 스크롤할 때 살짝의 흔들림은 탭으로 처리해야 한다.
	scroll_deadzone = 12


func build(layout: Dictionary, slot_count: int) -> void:
	var size_data: Dictionary = layout.get("panorama_size", {})
	var panorama_size := Vector2(
		float(size_data.get("width", 2400)),
		float(size_data.get("height", 380)),
	)

	_canvas = Control.new()
	_canvas.custom_minimum_size = panorama_size
	add_child(_canvas)

	_add_ground(panorama_size)

	var slots: Array = layout.get("slots", [])
	for slot_index in slot_count:
		var position := Vector2(240.0 * slot_index, 180.0)
		if slot_index < slots.size():
			position = Vector2(float(slots[slot_index].get("x", 0)), float(slots[slot_index].get("y", 0)))
		_add_slot_button(slot_index, position)


## 땅바닥 띠. 건물이 허공에 떠 있어 보이지 않게 하는 최소한의 장치다.
func _add_ground(panorama_size: Vector2) -> void:
	var ground := ColorRect.new()
	ground.color = COLOR_GROUND
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.position = Vector2(0, panorama_size.y * 0.55)
	ground.size = Vector2(panorama_size.x, panorama_size.y * 0.45)
	_canvas.add_child(ground)


func _add_slot_button(slot_index: int, slot_position: Vector2) -> void:
	var button := Button.new()
	button.position = slot_position
	button.custom_minimum_size = SLOT_SIZE
	button.size = SLOT_SIZE
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func() -> void: slot_pressed.emit(slot_index))
	_canvas.add_child(button)
	_slot_buttons.append(button)


## 마을 상태를 화면에 반영한다. 커맨드가 성공했거나 하루가 지날 때 불린다.
func refresh(village: SimVillage) -> void:
	for slot_index in _slot_buttons.size():
		_refresh_slot(_slot_buttons[slot_index], village, slot_index)


func _refresh_slot(button: Button, village: SimVillage, slot_index: int) -> void:
	if not village.is_slot_unlocked(slot_index):
		_style_slot(button, COLOR_LOCKED)
		button.text = "잠김\n%d년차" % village.slot_unlock_years[slot_index]
		button.disabled = true
		return

	button.disabled = false

	var building := village.building_at(slot_index)
	if building == null:
		_style_slot(button, COLOR_EMPTY)
		button.text = "+ 빈 자리"
		return

	var building_name := BuildingDisplay.name_of(building.type_id)

	if not building.is_complete():
		_style_slot(button, COLOR_BUILDING)
		# 남은 일수를 그대로 보여준다. 진행 바보다 "며칠 남았나"가 판단에 쓰인다.
		button.text = "%s\n건설 중 · %d일 남음" % [building_name, building.days_remaining]
		return

	# 멈춰 있는 건물은 색까지 바꾼다. 파노라마를 훑기만 해도
	# 문제가 있는 건물이 눈에 띄어야 한다 (ARCHITECTURE §6.3).
	if building.is_halted():
		_style_slot(button, COLOR_HALTED)
		button.text = "%s\n⚠ %s" % [building_name, BuildingDisplay.halt_badge(building.halt_reason)]
		return

	_style_slot(button, COLOR_ACTIVE)

	var capacity := village.worker_capacity(slot_index)
	if capacity <= 0:
		button.text = building_name
	else:
		button.text = "%s\n%d / %d" % [
			building_name, village.labor.assigned_to(slot_index), capacity]


func _style_slot(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color if state != "hover" else color.lightened(0.08)
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.15)
		button.add_theme_stylebox_override(state, style)
