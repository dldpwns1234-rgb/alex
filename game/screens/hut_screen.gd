class_name HutScreen
extends BuildingScreen

## 오두막 (GDD §4.1 — 인구는 숫자가 아니라 가구다).
##
## 오두막은 생산하지 않는다. 대신 **일자리의 상한**을 정한다.
## 가구 하나 = 오두막 하나 = 일자리 하나이므로, 오두막을 더 짓지 않으면
## 아무리 건물을 세워도 돌릴 사람이 없다.
##
## 이 화면이 답하는 것: 지금 사람이 부족한가, 집이 부족한가, 식량이 부족한가.
## 셋 중 무엇을 먼저 해결해야 하는지가 다르기 때문에 나눠서 보여준다.

var _rows: Dictionary = {}
var _verdict: Label


func _build_unique_area() -> Control:
	var panel := _panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title := Label.new()
	title.text = "거주 현황"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	for key in ["families", "housing", "idle", "food"]:
		column.add_child(_build_row(key))

	_verdict = Label.new()
	_verdict.add_theme_font_size_override("font_size", 21)
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_verdict)

	return panel


const ROW_LABELS := {
	"families": "가구",
	"housing": "주거",
	"idle": "유휴 인력",
	"food": "식량",
}


func _build_row(key: String) -> Control:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = ROW_LABELS[key]
	name_label.add_theme_font_size_override("font_size", 23)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 23)
	row.add_child(value_label)

	_rows[key] = value_label
	return row


func refresh_unique() -> void:
	if _verdict == null:
		return

	var labor := village().labor
	var housing := village().housing_capacity()
	var days := village().food_days_remaining()
	var required_days := village().rules.immigration_food_days_required

	_rows["families"].text = "%d가구" % labor.total()
	_rows["housing"].text = "%d / %d" % [labor.total(), housing]
	_rows["idle"].text = "%d가구" % labor.idle_count()
	_rows["food"].text = "%d일치" % days

	_rows["housing"].modulate = Color(1, 0.85, 0.6) if labor.total() >= housing \
		else Color(1, 1, 1, 0.8)
	_rows["idle"].modulate = Color(0.8, 1.0, 0.8) if labor.idle_count() > 0 \
		else Color(1, 1, 1, 0.5)

	_verdict.text = _immigration_verdict(labor.total(), housing, days, required_days)


## 이주민이 왜 오지 않는지 한 줄로 답한다.
## 조건이 두 개(집·식량)라서, 어느 쪽이 막고 있는지 모르면 손을 못 댄다.
func _immigration_verdict(families: int, housing: int, days: int, required_days: int) -> String:
	if families >= housing:
		return "빈 집이 없다. 오두막을 더 지어야 사람이 온다"
	if days < required_days:
		return "식량이 %d일치뿐이다. %d일치는 있어야 이주해 온다" % [days, required_days]
	return "빈 집과 식량이 있다. 곧 이주해 온다"
