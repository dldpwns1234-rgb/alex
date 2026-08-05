class_name StorehouseScreen
extends BuildingScreen

## 창고 (GDD §4.6 — 배급 정책).
##
## 두 가지를 보여준다:
##   1. **며칠 버틸 수 있는가** — 이 게임에서 가장 중요한 숫자
##   2. 배급 정책 — 좋은 것부터 먹을 것인가, 아껴둘 것인가
##
## 저장 한도가 유한하기 때문에 배급 정책이 공짜 선택이 아니다.
## 빵은 한 칸에 다섯 끼니가 들어가므로 비축 효율이 가장 좋다.
## 잡곡부터 먹으면 빵이 쌓여 겨울 대비가 되지만, 그동안 잡곡이 창고를 차지한다.
##
## TODO(M4): 병사 vs 주민 우선순위. 병사는 일반 가구의 2배를 먹는다 (GDD §4.2).
## TODO(M3): 겨울 배급량 조절.

var _days_label: Label
var _policy_buttons: Dictionary = {}
var _policy_note: Label
var _capacity_rows: Array[Dictionary] = []


func _build_unique_area() -> Control:
	var panel := _panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	_days_label = Label.new()
	_days_label.add_theme_font_size_override("font_size", 34)
	column.add_child(_days_label)

	column.add_child(_build_policy_section())
	column.add_child(_build_capacity_section())

	return panel


func _build_policy_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "배급 정책"
	title.add_theme_font_size_override("font_size", 26)
	section.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	section.add_child(row)

	for policy in SimSetRationCommand.VALID_POLICIES:
		var button := Button.new()
		button.text = BuildingDisplay.ration_name(policy)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, MIN_TOUCH_PX * 0.7)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_policy_chosen.bind(policy))
		row.add_child(button)
		_policy_buttons[policy] = button

	_policy_note = Label.new()
	_policy_note.add_theme_font_size_override("font_size", 20)
	_policy_note.modulate = Color(1, 1, 1, 0.55)
	_policy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(_policy_note)

	return section


## 어느 자원이 창고를 얼마나 차지하고 있는가.
## 가득 찬 자원이 있으면 그 생산 라인이 멈춰 있다는 뜻이다.
func _build_capacity_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "저장 현황"
	title.add_theme_font_size_override("font_size", 26)
	section.add_child(title)

	for resource_id in ResourceDisplay.ordered(village().resources.tracked_ids()):
		var row := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = ResourceDisplay.name_of(resource_id)
		name_label.add_theme_font_size_override("font_size", 21)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var amount_label := Label.new()
		amount_label.add_theme_font_size_override("font_size", 21)
		row.add_child(amount_label)

		section.add_child(row)
		_capacity_rows.append({"id": resource_id, "label": amount_label})

	return section


func _on_policy_chosen(policy: String) -> void:
	Game.world.execute(SimSetRationCommand.new(policy))


func refresh_unique() -> void:
	if _days_label == null:
		return

	var food_days := village().food_days_remaining()
	var firewood_days := village().firewood_days_remaining()
	_days_label.text = "식량 %d일 · 장작 %d일" % [food_days, firewood_days]

	# 급한 쪽에 색을 맞춘다. 열흘은 이주민이 오는 기준선이기도 하다 (rules.json).
	var days := mini(food_days, firewood_days)
	if days <= 3:
		_days_label.modulate = Color(1, 0.55, 0.55)
	elif days < 10:
		_days_label.modulate = Color(1, 0.85, 0.6)
	else:
		_days_label.modulate = Color(0.8, 1.0, 0.8)

	var policy := village().ration_policy
	for key in _policy_buttons:
		_policy_buttons[key].button_pressed = (key == policy)
	_policy_note.text = BuildingDisplay.ration_description(policy)

	for row in _capacity_rows:
		var id: String = row["id"]
		var amount := village().resources.amount_of(id)
		var capacity := village().storage_capacity(id)
		row["label"].text = "%d / %d" % [amount, capacity]
		row["label"].modulate = Color(1, 0.7, 0.6) if amount >= capacity \
			else Color(1, 1, 1, 0.75)
