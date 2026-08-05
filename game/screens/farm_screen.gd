class_name FarmScreen
extends BuildingScreen

## 농장 (GDD §4.6 — 작물 선택).
##
## 작물 자체는 공통 레시피 선택으로 고른다. 고유 영역이 답하는 것은
## **"그래서 뭘 심어야 하나"** 다.
##
## 순무는 심으면 바로 먹는다. 밀은 방앗간과 화덕을 거쳐야 값을 한다.
## 이 비교를 플레이어가 암산하게 두면 아무도 밀을 심지 않으므로,
## 가공까지 포함한 효율을 숫자로 보여준다 (SimEconomy).
##
## TODO(M3): 파종 시기와 휴경. 계절이 생산에 걸리기 시작하면 그때 의미가 생긴다.

var _rows: Array[Dictionary] = []
var _chain_label: Label


func _build_unique_area() -> Control:
	var panel := _panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title := Label.new()
	title.text = "작물 비교"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var note := Label.new()
	note.text = "가구일당 몇 끼니인가 — 가공까지 따진 값"
	note.add_theme_font_size_override("font_size", 20)
	note.modulate = Color(1, 1, 1, 0.5)
	column.add_child(note)

	var economy := SimEconomy.new(village().catalog, village().resource_catalog)
	for recipe in building_type().recipes:
		column.add_child(_build_row(recipe, economy))

	_chain_label = Label.new()
	_chain_label.add_theme_font_size_override("font_size", 21)
	_chain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_chain_label)

	return panel


func _build_row(recipe: SimRecipe, economy: SimEconomy) -> Control:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = BuildingDisplay.recipe_name(type_id, recipe.id)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = "%.2f 끼니" % economy.food_per_worker_day(recipe)
	value_label.add_theme_font_size_override("font_size", 24)
	row.add_child(value_label)

	_rows.append({"recipe_id": recipe.id, "name": name_label, "value": value_label})
	return row


func refresh_unique() -> void:
	var current := building()
	if current == null:
		return

	# 지금 심고 있는 작물을 밝게, 나머지는 흐리게.
	for row in _rows:
		var selected: bool = row["recipe_id"] == current.recipe_id
		var alpha := 1.0 if selected else 0.45
		row["name"].modulate = Color(1, 1, 1, alpha)
		row["value"].modulate = Color(0.8, 1.0, 0.8, alpha) if selected else Color(1, 1, 1, alpha)

	_chain_label.text = _chain_warning(current.recipe_id)
	_chain_label.modulate = Color(1, 0.8, 0.55) if not _chain_label.text.is_empty() \
		else Color(1, 1, 1, 0.6)


## 지금 고른 작물이 가공을 필요로 하는데 그 건물이 없으면 알려준다.
## 밀만 잔뜩 쌓아두고 굶는 상황을 막는 안내다.
func _chain_warning(recipe_id: String) -> String:
	var recipe := building_type().get_recipe(recipe_id)
	if recipe == null:
		return ""

	var needs_processing := false
	for resource_id in recipe.outputs:
		if not village().resource_catalog.is_food(String(resource_id)):
			needs_processing = true

	if not needs_processing:
		return "심으면 바로 먹을 수 있다"

	var missing := _missing_processors()
	if missing.is_empty():
		return "가공 시설이 갖춰져 있다"
	return "%s이(가) 없으면 먹을 수 없다" % BuildingDisplay.requirement_list(missing)


## 밀을 빵으로 만드는 데 필요한데 아직 완공되지 않은 건물들.
func _missing_processors() -> Array[String]:
	var completed := village().completed_type_ids()
	var missing: Array[String] = []
	for type_id_candidate in village().catalog.ids():
		var type := village().catalog.get_type(type_id_candidate)
		for recipe in type.recipes:
			if recipe.is_gathering():
				continue
			# 먹을 수 없는 것을 재료로 받는 건물 = 가공 시설
			for input_id in recipe.inputs:
				if not village().resource_catalog.is_food(String(input_id)) \
					and not completed.has(type_id_candidate) \
					and not missing.has(type_id_candidate):
					missing.append(type_id_candidate)
	return missing
