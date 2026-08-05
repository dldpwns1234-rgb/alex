class_name SimEconomy
extends RefCounted

## 가공 사슬의 값어치를 계산한다.
##
## 답하려는 질문: **"밀을 심는 게 순무보다 나은가?"**
##
## 순무는 심으면 바로 먹는다. 밀은 날로 못 먹고 방앗간과 화덕을 거쳐야
## 빵이 된다. 두 선택을 비교하려면 가공에 드는 인력까지 합쳐야 하고,
## 그것을 손으로 계산하게 두면 플레이어는 그냥 순무만 심는다.
##
## sim에 두는 이유는 M6 밸런싱 하네스(ARCHITECTURE §8)가 같은 계산을 쓰기 때문이다.
## "밀 사슬이 순무보다 못하다"는 표시가 아니라 밸런스 버그다.

## 자원 한 단위의 최종 값어치.
class UnitValue extends RefCounted:
	## 끝까지 가공했을 때 나오는 끼니 수.
	var food: float = 0.0
	## 거기까지 가는 데 드는 '가구 × 일'.
	var worker_days: float = 0.0

	func _init(food_value: float = 0.0, cost: float = 0.0) -> void:
		food = food_value
		worker_days = cost


var _catalog: SimBuildingCatalog
var _resources: SimResourceCatalog
var _cache: Dictionary = {}


func _init(building_catalog: SimBuildingCatalog, resource_catalog: SimResourceCatalog) -> void:
	_catalog = building_catalog
	_resources = resource_catalog


## 레시피 한 번 돌렸을 때 얻는 끼니를, 거기 드는 총 가구일로 나눈 값.
##
## 농장의 세 작물을 이 값으로 비교하면 "밀이 결국 더 낫다"가 숫자로 보인다.
## 만들어봐야 못 먹는 것이면 0이다.
func food_per_worker_day(recipe: SimRecipe) -> float:
	var total_food := 0.0
	var total_days := float(recipe.worker_days)

	for resource_id in recipe.outputs:
		var quantity := float(recipe.outputs[resource_id])
		var value := unit_value(String(resource_id))
		total_food += value.food * quantity
		total_days += value.worker_days * quantity

	if total_days <= 0.0:
		return 0.0
	return total_food / total_days


## 자원 한 단위를 끝까지 가공했을 때의 값어치.
##
## 먹을 수 있으면 거기서 끝난다. 못 먹으면 이 자원을 재료로 쓰는 레시피를 찾아
## 그 산출물의 값어치를 재귀로 따라간다.
func unit_value(resource_id: String) -> UnitValue:
	return _unit_value(resource_id, {})


func _unit_value(resource_id: String, visiting: Dictionary) -> UnitValue:
	if _cache.has(resource_id):
		return _cache[resource_id]

	var direct := _resources.food_value(resource_id)
	if direct > 0:
		var value := UnitValue.new(float(direct), 0.0)
		_cache[resource_id] = value
		return value

	# 레시피가 순환하면(A→B→A) 무한 재귀가 된다. 데이터 실수로 게임이
	# 멈추지 않도록 방문 중인 자원은 값어치 0으로 끊는다.
	if visiting.has(resource_id):
		return UnitValue.new()

	visiting[resource_id] = true
	var best := UnitValue.new()

	for consumer in _recipes_consuming(resource_id):
		var candidate := _value_through(resource_id, consumer, visiting)
		if candidate.food > best.food:
			best = candidate

	visiting.erase(resource_id)

	# 순환 판정 중에 나온 값은 불완전할 수 있으므로 캐시하지 않는다.
	if visiting.is_empty():
		_cache[resource_id] = best
	return best


## 이 레시피를 거쳐 갔을 때 자원 한 단위가 갖는 값어치.
func _value_through(resource_id: String, recipe: SimRecipe, visiting: Dictionary) -> UnitValue:
	var consumed := float(recipe.inputs.get(resource_id, 0))
	if consumed <= 0.0:
		return UnitValue.new()

	var food := 0.0
	var days := float(recipe.worker_days)

	for output_id in recipe.outputs:
		var quantity := float(recipe.outputs[output_id])
		var value := _unit_value(String(output_id), visiting)
		food += value.food * quantity
		days += value.worker_days * quantity

	return UnitValue.new(food / consumed, days / consumed)


func _recipes_consuming(resource_id: String) -> Array[SimRecipe]:
	var found: Array[SimRecipe] = []
	for type_id in _catalog.ids():
		for recipe in _catalog.get_type(type_id).recipes:
			if recipe.inputs.has(resource_id):
				found.append(recipe)
	return found
