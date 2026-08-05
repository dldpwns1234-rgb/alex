class_name HomeScreen
extends Control

## 홈 화면 — 마을 전경 (GDD §4.6).
##
## 세로 화면 구성:
##   상단 — 날짜 · 생명 신호 · 자원
##   중앙 — 세로 스크롤 파노라마 (건물 슬롯)
##   하단 — 안내 문구 · 게임 속도
##
## 속도 버튼을 맨 아래에 두는 이유는 한 손 조작이다 (ARCHITECTURE §12.2).
## 세로로 든 폰에서 엄지가 편하게 닿는 곳은 화면 아래쪽뿐이다.
## 반대로 정보(날짜·식량)는 위에 둔다 — 읽기만 하고 누르지 않기 때문이다.
##
## 이 화면은 sim 상태를 **읽기만** 한다. 건설은 커맨드로 나간다
## (ARCHITECTURE §2 규칙 4, §6.1 규칙 2).

## 터치 타겟 최소 크기.
##
## 뷰포트 가로 720px가 폰 가로 약 360dp에 대응하므로 1dp ≈ 2px이다.
## 안드로이드 접근성 가이드라인의 48dp는 여기서 96px이 된다
## (ARCHITECTURE §12.2).
const MIN_TOUCH_PX := 96

## 속도 버튼 높이. 최소 터치 타겟(96px)보다 낮지만 가로가 170px이라
## 누르기 어렵지 않다. 96px로 두면 화면 아래를 너무 많이 차지한다.
const SPEED_BUTTON_HEIGHT := 84

## 건설 실패 안내가 화면에 머무는 시간(초).
const TOAST_SECONDS := 2.5

var _background: ColorRect
var _vitals_label: Label
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
	Game.world.population_changed.connect(_on_population_changed)
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
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	# 하단 여백을 넉넉히 두는 이유: 요즘 안드로이드 폰의 제스처 바가
	# 화면 맨 아래를 차지한다. 버튼을 끝까지 붙이면 눌러야 할 때 홈으로 나가버린다.
	# TODO: 실기에서 DisplayServer.get_display_safe_area()로 정확히 맞춘다.
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	column.add_child(_build_top_bar())
	column.add_child(_build_panorama())
	column.add_child(_build_bottom_bar())


## 상단은 세 줄이다. 세로 화면에서는 가로로 늘어놓을 자리가 없다.
##
##   날짜        — 가장 크게. 계절이 곧 압박이다
##   생명 신호   — 가구 · 유휴 인력 · 식량/장작 며칠치
##   자원        — 가장 작게
##
## 이 순서인 이유: 목재가 몇인지보다 **"며칠 뒤에 굶는가"** 가 판단을 바꾼다.
func _build_top_bar() -> Control:
	var bar := VBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)

	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 34)
	bar.add_child(_date_label)

	_vitals_label = Label.new()
	_vitals_label.add_theme_font_size_override("font_size", 22)
	_vitals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_vitals_label)

	# 자원이 늘어나면 한 줄을 넘긴다. 잘라내지 않고 접는다
	# — 화면에서 사라진 자원은 없는 자원처럼 보인다.
	_resource_label = Label.new()
	_resource_label.add_theme_font_size_override("font_size", 18)
	_resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resource_label.modulate = Color(1, 1, 1, 0.62)
	bar.add_child(_resource_label)

	return bar


func _build_panorama() -> Control:
	_panorama = VillagePanorama.new()
	_panorama.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panorama.build(SimJson.read_dict(SimVillage.LAYOUT_PATH), Game.world.village.slot_count())
	_panorama.slot_pressed.connect(_on_slot_pressed)
	return _panorama


## 하단 — 안내 문구 한 줄과 속도 버튼 네 개.
##
## 속도 버튼은 가로를 4등분해 꽉 채운다. 세로 화면 폭 720에서 하나당 약 170px이니
## 엄지로 눌러도 옆 버튼을 건드리지 않는다.
##
## 높이는 최소 터치 타겟(96px)보다 낮은 84px다. 가로가 170px이라
## 실제로 누르기 어렵지 않고, 96px로 두면 화면 아래를 너무 많이 차지한다.
## 정사각형에 가까운 버튼이었다면 96px를 지켰을 것이다.
func _build_bottom_bar() -> Control:
	var bar := VBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	# 건설 실패 사유와 인구 변동이 뜨는 자리. 평소에는 비어 있다.
	# 파노라마 바로 아래, 속도 버튼 바로 위 — 시선과 손이 모두 지나는 곳이다.
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.custom_minimum_size = Vector2(0, 30)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_toast_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	var group := ButtonGroup.new()
	for index in Game.SPEEDS.size():
		var button := Button.new()
		button.text = Game.SPEED_LABELS[index]
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(0, SPEED_BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Game.set_speed.bind(index))
		row.add_child(button)
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
	stack.push_screen(BuildingScreenFactory.create(slot_index, building.type_id))


func _on_building_chosen(slot_index: int, type_id: String) -> void:
	# 상태 변경은 반드시 커맨드를 거친다 (ARCHITECTURE §2 규칙 4).
	var error := Game.world.execute(SimBuildCommand.new(slot_index, type_id))

	var stack := get_parent() as ScreenStack
	if stack != null:
		stack.pop_screen()

	if error != SimCommand.OK:
		_show_toast(BuildingDisplay.command_error_message(error), Color(1, 0.7, 0.7))


## 잠깐 떴다 사라지는 안내. 실패했는데 아무 반응이 없으면
## 플레이어는 탭이 씹혔다고 생각한다.
func _show_toast(message: String, color: Color) -> void:
	_toast_label.text = message
	_toast_label.modulate = color

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


func _on_population_changed(event: String, _total: int) -> void:
	# 인구 변동은 놓치면 안 되는 사건이다. 마을을 떠나는 것은 특히 그렇다.
	var color := Color(1, 0.6, 0.6) if event == "family_left" else Color(0.75, 1, 0.8)
	_show_toast(BuildingDisplay.population_event_message(event), color)


func _refresh_village() -> void:
	var village := Game.world.village
	_panorama.refresh(village)
	_resource_label.text = ResourceDisplay.format_stock(village.resources)

	var food_days := village.food_days_remaining()
	var firewood_days := village.firewood_days_remaining()
	_vitals_label.text = "%d가구 · 유휴 %d · 식량 %d일 · 장작 %d일" % [
		village.labor.total(), village.labor.idle_count(), food_days, firewood_days]

	# 둘 중 급한 쪽으로 색을 맞춘다. 식량이 넉넉해도 장작이 떨어지면 가구는 떠난다.
	# 사흘 남으면 빨간불이지만, 그때는 이미 늦은 경우가 많아 열흘부터 노란불을 켠다.
	var days := mini(food_days, firewood_days)
	if days <= 3:
		_vitals_label.modulate = Color(1, 0.55, 0.55)
	elif days < 10:
		_vitals_label.modulate = Color(1, 0.87, 0.6)
	else:
		_vitals_label.modulate = Color(1, 1, 1)
