class_name SimVillage
extends RefCounted

## 마을 — 자원 · 슬롯 · 건물 · 가구 (GDD §4.1, §4.5).
##
## 하루의 순서가 중요하다:
##   건설 → 생산 → 소비 → 인구
## 생산이 소비보다 먼저인 이유는, 그날 거둔 것을 그날 먹을 수 있어야
## 플레이어의 판단("지금 인력을 농장으로 돌리면 살 수 있나")이 성립하기 때문이다.

const LAYOUT_PATH := "res://data/village_layout.json"

## 배급 정책 (GDD §4.6 — 창고에서 정하는 결정).
##
## 저장 한도가 유한하기 때문에 이 선택이 의미를 갖는다.
## 빵은 한 칸에 다섯 끼니가 들어가므로 비축 효율이 가장 좋다.
## 순무부터 먹으면 빵이 쌓여 겨울 대비가 되지만, 순무가 창고를 차지한다.
const RATION_RICH_FIRST := "rich_first"
const RATION_CHEAP_FIRST := "cheap_first"

## 슬롯 해금 조건. M1에서는 연차뿐이다.
## TODO(M4): 인구 · 명성 조건 추가 (GDD §4.5).
var slot_unlock_years: Array[int] = []

var resources := SimResourcePool.new()
var catalog: SimBuildingCatalog
var resource_catalog: SimResourceCatalog
var rules: SimRules
var labor := SimLabor.new()

## 슬롯 번호 → SimBuilding. 비어 있는 슬롯은 키가 없다.
var buildings: Dictionary = {}

## 현재 연차 기준으로 해금된 슬롯 수. world가 틱마다 갱신한다.
var unlocked_slot_count: int = 0

## 지금 계절. world가 틱마다 갱신한다.
## 생산·소비 배율이 여기 걸리므로, 마을은 "지금이 겨울인가"를 알아야 한다.
var season: SimCalendar.Season = SimCalendar.Season.SPRING

var ration_policy: String = RATION_RICH_FIRST

## 쌓인 고난 — 못 먹은 끼니와 못 땐 장작의 합.
##
## **연속 일수가 아니라 누적량이다.** 하루 굶고 하루 먹기를 반복하는 마을은
## 연속 일수로 세면 매번 0으로 초기화되어, 필요량의 60%만 먹으면서도
## 영원히 버틴다. 만성 부족이 아무 결과도 낳지 않는 것은 규칙의 구멍이다.
##
## 굶주림과 추위를 한 저울에 올리는 이유: 가구가 떠나는 것은 "살 만한가"의
## 문제이지 어느 항목이 모자랐는가의 문제가 아니다.
## 무엇이 모자랐는지는 last_shortage가 답한다.
var hardship: int = 0
## "" · "food" · "firewood" · "both" — 한글 문구는 game 계층의 몫이다.
var last_shortage: String = ""

## 직전 consume()에서 채우지 못한 양. update_population()이 고난으로 환산한다.
var _unmet: int = 0
var _days_since_immigration: int = 0


static func load_default() -> SimVillage:
	return from_json(
		SimJson.read_dict(LAYOUT_PATH),
		SimBuildingCatalog.load_default(),
		SimResourceCatalog.load_default(),
		SimRules.load_default(),
	)


static func from_json(
	layout: Dictionary,
	building_catalog: SimBuildingCatalog,
	resources_catalog: SimResourceCatalog,
	village_rules: SimRules,
) -> SimVillage:
	var village := SimVillage.new()
	village.catalog = building_catalog
	village.resource_catalog = resources_catalog
	village.rules = village_rules
	village.resources = SimResourcePool.from_dict(layout.get("starting_resources", {}))

	for slot in layout.get("slots", []):
		village.slot_unlock_years.append(int(slot.get("unlock_year", 1)))

	for _i in village_rules.starting_families:
		village.labor.add_family()

	village.refresh_slot_unlocks(1)
	return village


# --- 슬롯과 건물 ---------------------------------------------------------------

func slot_count() -> int:
	return slot_unlock_years.size()


func is_slot_unlocked(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < unlocked_slot_count


func building_at(slot_index: int) -> SimBuilding:
	return buildings.get(slot_index)


func is_slot_empty(slot_index: int) -> bool:
	return not buildings.has(slot_index)


func type_of(building: SimBuilding) -> SimBuildingType:
	return catalog.get_type(building.type_id)


## 슬롯 번호 오름차순. 딕셔너리 순회 순서에 결과가 좌우되지 않게 한다
## — 결정론은 밸런싱과 리플레이의 전제다 (ARCHITECTURE §2).
func occupied_slots() -> Array:
	var slots := buildings.keys()
	slots.sort()
	return slots


## 완공된 건물의 종류 id 집합. 해금 사슬 판정에 쓴다 (GDD §4.5).
##
## 건설 중인 건물은 제외한다 — 짓기 시작하자마자 다음 단계가 열리면
## 건설 일수가 아무 의미도 갖지 못한다.
func completed_type_ids() -> Dictionary:
	var completed := {}
	for slot_index in buildings:
		var building: SimBuilding = buildings[slot_index]
		if building.is_complete():
			completed[building.type_id] = true
	return completed


func is_type_unlocked(type_id: String) -> bool:
	return catalog.is_unlocked(type_id, completed_type_ids())


# --- 수용력 -------------------------------------------------------------------

## 살 수 있는 가구 수. 오두막이 곧 인구 상한이다 (GDD §4.1).
func housing_capacity() -> int:
	var total := 0
	for slot_index in buildings:
		var building: SimBuilding = buildings[slot_index]
		if building.is_complete():
			total += type_of(building).housing
	return total


## 자원별 저장 한도. 기본값 + 창고들이 더해주는 값.
func storage_capacity(resource_id: String) -> int:
	var total := resource_catalog.base_capacity(resource_id)
	for slot_index in buildings:
		var building: SimBuilding = buildings[slot_index]
		if building.is_complete():
			total += type_of(building).storage
	return total


func worker_capacity(slot_index: int) -> int:
	var building := building_at(slot_index)
	if building == null or not building.is_complete():
		return 0
	return type_of(building).workers


# --- 하루 진행 ----------------------------------------------------------------

## 하루치 건설 진행. 그날 완공된 건물들을 반환한다.
func advance_construction() -> Array[SimBuilding]:
	var completed: Array[SimBuilding] = []
	for slot_index in occupied_slots():
		var building: SimBuilding = buildings[slot_index]
		if building.advance_construction():
			completed.append(building)
	return completed


## 하루치 생산.
##
## 인력이 붙어 있는 만큼 진행이 쌓이고, worker_days를 채울 때마다 산출한다.
## 4배속에서 하루에 여러 번 산출될 수 있으므로 while로 돈다.
func produce() -> void:
	for slot_index in occupied_slots():
		var building: SimBuilding = buildings[slot_index]
		if not building.is_complete():
			continue

		var type := type_of(building)
		if not type.produces():
			continue

		_produce_one(building, type, labor.assigned_to(slot_index))


func _produce_one(building: SimBuilding, type: SimBuildingType, workers: int) -> void:
	# 농경은 겨울에 아예 멈춘다 (GDD §3.2). 인력을 더 넣어도 소용없으므로
	# "인력 없음"이 아니라 별도의 상태로 보여준다.
	if type.seasonal and season == SimCalendar.Season.WINTER:
		building.halt_reason = SimBuilding.HALT_WINTER
		return

	if workers <= 0:
		building.halt_reason = SimBuilding.HALT_NO_WORKERS
		return

	var recipe := type.get_recipe(building.recipe_id)
	if recipe == null:
		# 데이터가 바뀌어 예전 레시피가 사라진 경우. 기본값으로 되돌린다.
		building.set_recipe(type.default_recipe_id())
		recipe = type.get_recipe(building.recipe_id)
		if recipe == null:
			return

	building.halt_reason = SimBuilding.HALT_NONE
	building.production_progress += workers * rules.production_multiplier(season)

	while building.production_progress >= recipe.worker_days:
		if not resources.can_afford(recipe.inputs):
			building.halt_reason = SimBuilding.HALT_NO_INPUT
			return
		if not _has_room_for(recipe.outputs):
			# 재료를 쓰고 나서 버리게 두지 않는다. 넣을 자리가 없으면 아예 멈춘다.
			building.halt_reason = SimBuilding.HALT_STORAGE_FULL
			return

		building.production_progress -= recipe.worker_days
		resources.spend(recipe.inputs)
		for resource_id in recipe.outputs:
			_add_capped(String(resource_id), int(recipe.outputs[resource_id]))


func _has_room_for(outputs: Dictionary) -> bool:
	for resource_id in outputs:
		var id := String(resource_id)
		if resources.amount_of(id) >= storage_capacity(id):
			return false
	return true


func _add_capped(resource_id: String, amount: int) -> void:
	var capacity := storage_capacity(resource_id)
	var room := maxi(0, capacity - resources.amount_of(resource_id))
	resources.add(resource_id, mini(amount, room))


## 하루치 소비. 먹이고 데우는 데 성공했으면 true.
##
## 장작이 식량과 같은 무게를 갖는 것이 나무꾼 오두막의 선택을 진짜로 만든다.
## 장작이 부족해도 아무 일이 없으면 "목재 채취"가 언제나 정답이 되고,
## 그 순간 그 건물의 레시피 선택은 장식이 된다.
func consume() -> bool:
	var families := labor.total()
	_unmet = 0
	if families <= 0:
		last_shortage = ""
		return true

	var unmet_firewood := _burn(families)
	var unmet_food := _feed(families)
	_unmet = unmet_food + unmet_firewood

	if unmet_food > 0 and unmet_firewood > 0:
		last_shortage = "both"
	elif unmet_food > 0:
		last_shortage = "food"
	elif unmet_firewood > 0:
		last_shortage = "firewood"
	else:
		last_shortage = ""

	return _unmet <= 0


## 못 땐 장작 수를 반환한다.
func _burn(families: int) -> int:
	var needed := daily_firewood(families)
	if needed <= 0:
		return 0

	var burned := mini(needed, resources.amount_of(rules.firewood_resource))
	resources.add(rules.firewood_resource, -burned)
	return needed - burned


## 못 먹은 끼니 수를 반환한다.
func _feed(families: int) -> int:
	var needed := daily_food(families)
	for resource_id in _ration_order():
		if needed <= 0:
			break
		needed -= _eat(resource_id, needed)
	return maxi(0, needed)


## 해당 자원을 먹어서 채운 끼니 수.
func _eat(resource_id: String, needed: int) -> int:
	var value := resource_catalog.food_value(resource_id)
	var available := resources.amount_of(resource_id)
	if value <= 0 or available <= 0:
		return 0

	# 마지막 한 단위는 남는 끼니가 버려질 수 있다.
	# 빵 하나로 두 끼니를 채우면 세 끼니가 사라지는데, 그것이 배급 정책이
	# 공짜 선택이 아닌 이유다.
	var units := mini(available, ceili(float(needed) / float(value)))
	resources.add(resource_id, -units)
	return units * value


func _ration_order() -> Array[String]:
	var ids := resource_catalog.food_ids()
	var catalog_ref := resource_catalog
	if ration_policy == RATION_CHEAP_FIRST:
		ids.sort_custom(func(a: String, b: String) -> bool:
			return catalog_ref.food_value(a) < catalog_ref.food_value(b))
	else:
		ids.sort_custom(func(a: String, b: String) -> bool:
			return catalog_ref.food_value(a) > catalog_ref.food_value(b))
	return ids


## 저장된 식량이 몇 끼니인가. 이주 판정과 화면 표시에 쓴다.
func food_stock_units() -> int:
	var total := 0
	for resource_id in resource_catalog.food_ids():
		total += resources.amount_of(resource_id) * resource_catalog.food_value(resource_id)
	return total


## 오늘 하루에 필요한 양. 계절 배율이 걸린다.
##
## 올림하는 이유: 여름 장작 0.5배에 2가구면 1.0이지만, 1가구면 0.5다.
## 내림하면 소비가 0이 되어 "여름에는 장작이 공짜"가 된다.
func daily_food(families: int) -> int:
	return ceili(rules.food_per_family * families * rules.food_multiplier(season))


func daily_firewood(families: int) -> int:
	return ceili(rules.firewood_per_family * families * rules.firewood_multiplier(season))


## 지금 인구로 며칠을 버틸 수 있는가. 화면에 띄우는 가장 중요한 숫자다.
##
## **지금 계절 기준이다.** 겨울에 접어들면 같은 비축량이 절반의 날수로 보인다.
## 그것이 정확한 정보다 — 가을에 보이던 "30일치"가 겨울에 "15일치"가 되는 것이
## 이 게임이 주려는 초조함이다 (GDD §1.4).
func food_days_remaining() -> int:
	var daily := daily_food(labor.total())
	if daily <= 0:
		return 0
	@warning_ignore("integer_division")
	return food_stock_units() / daily


## 장작으로 며칠을 버틸 수 있는가. 겨울이 오면 이 숫자가 식량만큼 중요해진다.
func firewood_days_remaining() -> int:
	var daily := daily_firewood(labor.total())
	if daily <= 0:
		return 0
	@warning_ignore("integer_division")
	return resources.amount_of(rules.firewood_resource) / daily


## 가구 하나가 떠나기까지 남은 고난. 화면의 위기 표시에 쓴다.
func hardship_limit() -> int:
	return rules.hardship_per_family_before_leaving * maxi(1, labor.total())


## 인구 변동. 그날 일어난 일을 코드로 반환한다 ("" = 변화 없음).
func update_population(provided_for: bool) -> String:
	if provided_for:
		# 오늘 배불리 먹었다고 어제 굶은 것이 없던 일이 되지는 않는다.
		# 갚는 속도를 쌓이는 속도보다 느리게 두는 이유가 그것이다.
		hardship = maxi(0, hardship - rules.hardship_recovery_per_day)
	else:
		hardship += _unmet
		if hardship >= hardship_limit():
			hardship = 0
			if labor.remove_family():
				return "family_left"
		return ""

	_days_since_immigration += 1
	if _days_since_immigration < rules.immigration_interval_days:
		return ""

	_days_since_immigration = 0
	if labor.total() >= housing_capacity():
		return ""
	if food_days_remaining() < rules.immigration_food_days_required:
		return ""

	labor.add_family()
	return "family_arrived"


## 연차에 따라 슬롯을 해금한다.
##
## 슬롯은 데이터 파일 순서대로 열린다. 중간 슬롯이 먼저 열리는 일은 없다.
func refresh_slot_unlocks(year: int) -> int:
	var newly_unlocked := 0
	while unlocked_slot_count < slot_unlock_years.size():
		if slot_unlock_years[unlocked_slot_count] > year:
			break
		unlocked_slot_count += 1
		newly_unlocked += 1
	return newly_unlocked
