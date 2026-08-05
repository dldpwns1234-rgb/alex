class_name BuildingScreen
extends Control

## 건물 화면의 공통 골격 (ARCHITECTURE §6.2).
##
## 건물은 10~12종까지 늘어난다 (GDD §4.5). 종마다 화면을 처음부터 그리면
## 감당할 수 없으므로, **서브클래스가 채우는 곳은 고유 영역 하나뿐**이다.
##
## 베이스가 제공하는 것:
##   헤더      — 이름 · 설명 · 가동 상태
##   인력 배정 — 모든 건물 공통 (GDD §4.6 설계 규칙). 마을 전체에서 제로섬이다
##   생산      — 레시피 선택 · 투입/산출 · 진행률
##   푸터      — 뒤로
##
## 인력 조절을 슬라이더 대신 −/+ 버튼으로 둔 이유:
## 최대 인원이 2~3명인데 폰에서 슬라이더로 정확히 2를 집는 것은 어렵다.
## 버튼은 한 번에 하나씩, 빗나갈 일 없이 움직인다.

const MIN_TOUCH_PX := 96

var slot_index: int
var type_id: String

var _state_label: Label
var _worker_label: Label
var _idle_label: Label
var _flow_label: Label
var _progress_label: Label
var _recipe_buttons: Dictionary = {}


func _init(building_slot_index: int, building_type_id: String) -> void:
	slot_index = building_slot_index
	type_id = building_type_id


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	Game.world.day_advanced.connect(_on_world_changed)
	Game.world.village_changed.connect(_refresh)
	_refresh()


# --- 편의 접근자 (서브클래스가 쓴다) --------------------------------------------

func village() -> SimVillage:
	return Game.world.village


func building() -> SimBuilding:
	return village().building_at(slot_index)


func building_type() -> SimBuildingType:
	return village().catalog.get_type(type_id)


# --- UI 구성 -----------------------------------------------------------------

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.09, 0.10, 0.12, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

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

	column.add_child(_build_header())

	# 세로 화면이므로 위에서 아래로 쌓는다.
	#
	# 순서가 곧 중요도다: 인력 → 생산 → 건물 고유.
	# 인력 배정이 맨 위인 이유는 모든 건물에 있는 유일한 컨트롤이고,
	# 화면을 열자마자 손이 가는 곳이기 때문이다 (GDD §4.6 설계 규칙).
	#
	# 스크롤로 감싸는 이유: 고유 영역의 길이는 건물마다 다르고,
	# 폰 세로 길이도 기기마다 다르다. 잘려서 안 보이는 것보다 밀어서 보는 편이 낫다.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	body.add_child(_build_labor_panel())
	if building_type().produces():
		body.add_child(_build_production_panel())

	var unique := _build_unique_area()
	if unique != null:
		unique.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(unique)

	column.add_child(_build_footer())


func _build_header() -> Control:
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)

	var title := Label.new()
	title.text = BuildingDisplay.name_of(type_id)
	title.add_theme_font_size_override("font_size", 40)
	header.add_child(title)

	var description := Label.new()
	description.text = BuildingDisplay.description_of(type_id)
	description.add_theme_font_size_override("font_size", 21)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = Color(1, 1, 1, 0.5)
	header.add_child(description)

	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 24)
	header.add_child(_state_label)

	return header


## 모든 건물 화면에 있는 컨트롤. 인력은 마을 전체에서 제로섬이므로
## 여기서 늘린 만큼 어딘가가 줄어든다 (GDD §4.4의 2번).
func _build_labor_panel() -> Control:
	var panel := _panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	if building_type().workers <= 0:
		var note := Label.new()
		note.text = "인력이 필요하지 않은 건물이다"
		note.modulate = Color(1, 1, 1, 0.5)
		column.add_child(note)
		return panel

	var title := Label.new()
	title.text = "인력 배정"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)

	row.add_child(_stepper_button("−", -1))

	_worker_label = Label.new()
	_worker_label.add_theme_font_size_override("font_size", 34)
	_worker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_worker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_worker_label)

	row.add_child(_stepper_button("+", 1))

	_idle_label = Label.new()
	_idle_label.add_theme_font_size_override("font_size", 22)
	_idle_label.modulate = Color(1, 1, 1, 0.6)
	column.add_child(_idle_label)

	return panel


func _stepper_button(label: String, delta: int) -> Button:
	var button := Button.new()
	button.text = label
	button.add_theme_font_size_override("font_size", 42)
	button.custom_minimum_size = Vector2(MIN_TOUCH_PX * 1.3, MIN_TOUCH_PX)
	button.pressed.connect(_on_worker_delta.bind(delta))
	return button


func _build_production_panel() -> Control:
	var panel := _panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var recipes := building_type().recipes
	if recipes.size() > 1:
		var title := Label.new()
		title.text = "무엇을 만들까"
		title.add_theme_font_size_override("font_size", 28)
		column.add_child(title)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)

		for recipe in recipes:
			var button := Button.new()
			button.text = BuildingDisplay.recipe_name(type_id, recipe.id)
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(0, MIN_TOUCH_PX * 0.8)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_on_recipe_chosen.bind(recipe.id))
			row.add_child(button)
			_recipe_buttons[recipe.id] = button

	_flow_label = Label.new()
	_flow_label.add_theme_font_size_override("font_size", 26)
	column.add_child(_flow_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 22)
	_progress_label.modulate = Color(1, 1, 1, 0.6)
	column.add_child(_progress_label)

	return panel


## 서브클래스가 재정의하는 **유일한** 부분이다.
## null을 반환하면 고유 영역 없이 공통 골격만 나온다.
##
## 앞으로 여기에 들어갈 것 (GDD §4.6):
##   대장간 — 제작 큐, 마정석 부여 여부
##   훈련소 — 병사 개별 훈련 배정, 병종 전환
##   교역소 — 시세, 교역대 편성, 호위 배정
func _build_unique_area() -> Control:
	return null


## 뒤로 버튼은 화면 맨 아래 전폭이다.
## 세로로 든 폰에서 엄지가 확실히 닿는 곳은 여기뿐이고, 가장 자주 누르는 버튼이다.
## 안드로이드 뒤로가기 버튼으로도 같은 동작을 한다 (ScreenStack).
func _build_footer() -> Control:
	# TODO(M8): 업그레이드 · 철거 버튼 (ARCHITECTURE §6.2).
	var back := Button.new()
	back.text = "뒤로"
	back.custom_minimum_size = Vector2(0, MIN_TOUCH_PX)
	back.pressed.connect(_on_back_pressed)
	return back


## 서브클래스도 쓰는 패널 상자.
func _panel() -> PanelContainer:
	var panel := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)

	return panel


# --- 조작 --------------------------------------------------------------------

func _on_worker_delta(delta: int) -> void:
	var current := village().labor.assigned_to(slot_index)
	Game.world.execute(SimAssignWorkersCommand.new(slot_index, current + delta))


func _on_recipe_chosen(recipe_id: String) -> void:
	Game.world.execute(SimSetRecipeCommand.new(slot_index, recipe_id))


func _on_back_pressed() -> void:
	var stack := get_parent() as ScreenStack
	if stack != null:
		stack.pop_screen()


# --- 상태 반영 ---------------------------------------------------------------

func _on_world_changed(_elapsed_days: int) -> void:
	# 건물 화면에 들어와 있어도 시계는 계속 돈다 (ARCHITECTURE §6.1 규칙 3).
	_refresh()


func _refresh() -> void:
	_refresh_state()
	_refresh_labor()
	_refresh_production()
	refresh_unique()


## 서브클래스가 고유 영역을 다시 그릴 자리.
func refresh_unique() -> void:
	pass


func _refresh_state() -> void:
	var current := building()
	var date := SeasonDisplay.format_date(Game.world.calendar)

	if current == null:
		_state_label.text = date
	elif not current.is_complete():
		_state_label.text = "건설 중 · %d일 남음 · %s" % [current.days_remaining, date]
	elif current.is_halted():
		_state_label.text = "%s · %s" % [BuildingDisplay.halt_message(current.halt_reason), date]
		_state_label.modulate = Color(1, 0.72, 0.55)
	else:
		_state_label.text = "가동 중 · %s" % date
		_state_label.modulate = Color(0.75, 1.0, 0.78)


func _refresh_labor() -> void:
	if _worker_label == null:
		return

	var assigned := village().labor.assigned_to(slot_index)
	_worker_label.text = "%d / %d" % [assigned, building_type().workers]
	_idle_label.text = "유휴 가구 %d · 전체 %d가구" % [
		village().labor.idle_count(), village().labor.total()]


func _refresh_production() -> void:
	if _flow_label == null:
		return

	var current := building()
	if current == null:
		return

	for recipe_id in _recipe_buttons:
		_recipe_buttons[recipe_id].button_pressed = (recipe_id == current.recipe_id)

	var recipe := building_type().get_recipe(current.recipe_id)
	if recipe == null:
		return

	_flow_label.text = BuildingDisplay.format_recipe_flow(recipe)

	var note := BuildingDisplay.recipe_description(type_id, recipe.id)
	_progress_label.text = "%d / %d 가구일%s" % [
		current.production_progress,
		recipe.worker_days,
		"  —  " + note if not note.is_empty() else "",
	]
