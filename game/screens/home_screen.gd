class_name HomeScreen
extends Control

## 홈 화면 — 마을 전경 (GDD §4.6).
##
## 구성:
##   상단 — 자원 바 · 날짜/계절
##   중앙 — 가로 스크롤 파노라마 (건물 슬롯)
##   하단 — 안내 문구 · 게임 속도
##
## 이 화면은 sim 상태를 **읽기만** 한다. 건설은 커맨드로 나간다
## (ARCHITECTURE §2 규칙 4, §6.1 규칙 2).

## 터치 타겟 최소 크기.
##
## 뷰포트 세로 720px가 폰 세로 약 360dp에 대응하므로 1dp ≈ 2px이다.
## 안드로이드 접근성 가이드라인의 48dp는 여기서 96px이 된다
## (ARCHITECTURE §12.2).
const MIN_TOUCH_PX := 96

## 건설 실패 안내가 화면에 머무는 시간(초).
const TOAST_SECONDS := 2.5

var _background: ColorRect
var _resource_label: Label
var _date_label: Label
var _toast_label: Label
var _panorama: VillagePanorama
var _speed_buttons: Array[Button] = []
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	Game.world.day_advanced.connect(_on_day_advanced)
	Game.world.season_changed.connect(_on_season_changed)
	Game.world.village_changed.connect(_refresh_village)
	Game.speed_changed.connect(_on_speed_changed)

	_refresh_date()
	_refresh_season()
	_refresh_village()
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
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	column.add_child(_build_top_bar())
	column.add_child(_build_panorama())
	column.add_child(_build_bottom_bar())


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()

	_resource_label = Label.new()
	_resource_label.add_theme_font_size_override("font_size", 30)
	bar.add_child(_resource_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 38)
	bar.add_child(_date_label)

	return bar


func _build_panorama() -> Control:
	_panorama = VillagePanorama.new()
	_panorama.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panorama.build(SimJson.read_dict(SimVillage.LAYOUT_PATH), Game.world.village.slot_count())
	_panorama.slot_pressed.connect(_on_slot_pressed)
	return _panorama


func _build_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)

	# 건설 실패 사유가 뜨는 자리. 평소에는 비어 있다.
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 26)
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_toast_label)

	var group := ButtonGroup.new()
	for index in Game.SPEEDS.size():
		var button := Button.new()
		button.text = Game.SPEED_LABELS[index]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(MIN_TOUCH_PX * 1.2, MIN_TOUCH_PX)
		button.pressed.connect(Game.set_speed.bind(index))
		bar.add_child(button)
		_speed_buttons.append(button)

	return bar


# --- 슬롯 조작 ---------------------------------------------------------------

func _on_slot_pressed(slot_index: int) -> void:
	var stack := get_parent() as ScreenStack
	if stack == null:
		return

	var building := Game.world.village.building_at(slot_index)
	if building == null:
		var menu := BuildMenuScreen.new(slot_index, Game.world.village)
		menu.building_chosen.connect(_on_building_chosen)
		stack.push_screen(menu)
		return

	# 건설 중인 건물도 들어갈 수 있다. 얼마나 남았는지 보는 것도 정보다.
	stack.push_screen(BuildingScreen.new(slot_index, building.type_id))


func _on_building_chosen(slot_index: int, type_id: String) -> void:
	# 상태 변경은 반드시 커맨드를 거친다 (ARCHITECTURE §2 규칙 4).
	var error := Game.world.execute(SimBuildCommand.new(slot_index, type_id))

	var stack := get_parent() as ScreenStack
	if stack != null:
		stack.pop_screen()

	if error != SimCommand.OK:
		_show_toast(BuildingDisplay.build_error_message(error))


## 잠깐 떴다 사라지는 안내. 실패했는데 아무 반응이 없으면
## 플레이어는 탭이 씹혔다고 생각한다.
func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast_label.modulate = Color(1, 0.7, 0.7)

	var timer := get_tree().create_timer(TOAST_SECONDS)
	_toast_timer = timer
	await timer.timeout

	# 그 사이 새 안내가 떴다면 이 타이머의 결과는 버린다.
	if _toast_timer == timer and is_instance_valid(_toast_label):
		_toast_label.text = ""


# --- 상태 반영 ---------------------------------------------------------------

func _on_day_advanced(_elapsed_days: int) -> void:
	_refresh_date()
	# 건설 중인 슬롯의 "N일 남음"이 매일 줄어야 한다.
	# village_changed는 완공·해금 때만 오므로 그것만으로는 부족하다.
	_panorama.refresh(Game.world.village)


func _on_season_changed(_season: SimCalendar.Season) -> void:
	_refresh_season()


func _on_speed_changed(index: int) -> void:
	if index < _speed_buttons.size():
		_speed_buttons[index].button_pressed = true


func _refresh_date() -> void:
	_date_label.text = SeasonDisplay.format_date(Game.world.calendar)


func _refresh_season() -> void:
	_background.color = SeasonDisplay.color_of(Game.world.calendar.season())


func _refresh_village() -> void:
	var village := Game.world.village
	_panorama.refresh(village)
	_resource_label.text = ResourceDisplay.format_stock(village.resources)
