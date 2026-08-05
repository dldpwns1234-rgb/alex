class_name GameOverScreen
extends Control

## 승패 화면 (ROADMAP M3).
##
## M3에서 처음으로 게임이 **끝날 수 있게** 된다.
## 로드맵의 원칙이 그것이다 — "실패 조건이 없는 빌드는 게임이 아니라 장난감이다."
##
## 이겼든 졌든 **어떻게 그렇게 됐는지**를 보여준다.
## "마을이 사라졌다"만 띄우면 플레이어는 무엇을 잘못했는지 모른 채 다시 시작한다.

const MIN_TOUCH_PX := 96

var _outcome: String


func _init(outcome: String) -> void:
	_outcome = outcome


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.07, 0.09, 0.97) if _outcome == "defeat" \
		else Color(0.08, 0.11, 0.09, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer_top)

	column.add_child(_build_verdict())
	column.add_child(_build_summary())

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer_bottom)

	column.add_child(_build_restart_button())


func _build_verdict() -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = BuildingDisplay.outcome_title(_outcome)
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1, 0.65, 0.6) if _outcome == "defeat" else Color(0.8, 1, 0.82)
	block.add_child(title)

	var body := Label.new()
	body.text = BuildingDisplay.outcome_body(_outcome)
	body.add_theme_font_size_override("font_size", 22)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.modulate = Color(1, 1, 1, 0.6)
	block.add_child(body)

	return block


## 어디까지 갔는지. 다시 시작할 때 무엇을 다르게 해볼지 정하는 근거다.
func _build_summary() -> Control:
	var village := Game.world.village
	var calendar := Game.world.calendar

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var rows := [
		["버틴 기간", SeasonDisplay.format_date(calendar)],
		["남은 가구", "%d가구" % village.labor.total()],
		["지은 건물", "%d채" % village.buildings.size()],
		["마지막 부족", BuildingDisplay.shortage_message(village.last_shortage)],
	]

	for row_data in rows:
		if String(row_data[1]).is_empty():
			continue
		var row := HBoxContainer.new()

		var key := Label.new()
		key.text = String(row_data[0])
		key.add_theme_font_size_override("font_size", 22)
		key.modulate = Color(1, 1, 1, 0.55)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(key)

		var value := Label.new()
		value.text = String(row_data[1])
		value.add_theme_font_size_override("font_size", 22)
		row.add_child(value)

		column.add_child(row)

	return panel


func _build_restart_button() -> Control:
	var button := Button.new()
	button.text = "다시 시작"
	button.custom_minimum_size = Vector2(0, MIN_TOUCH_PX)
	# TODO(M8): 세이브가 생기면 "이어하기"도 여기 붙는다.
	button.pressed.connect(Game.restart)
	return button
