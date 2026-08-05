class_name SimResourceCatalog
extends RefCounted

## data/resources.json을 읽는다 (GDD §4.3).
##
## 자원의 두 가지 성질만 시뮬레이션에 필요하다:
##   food     — 가구가 먹을 때 몇 끼니 몫인가. 0이면 못 먹는다
##   capacity — 얼마나 쌓아둘 수 있는가. 창고가 이 값을 늘린다

const DATA_PATH := "res://data/resources.json"
const COMMENT_PREFIX := "_"

var _food: Dictionary = {}
var _capacity: Dictionary = {}
var _order: Array[String] = []


static func load_default() -> SimResourceCatalog:
	return from_json(SimJson.read_dict(DATA_PATH))


static func from_json(raw: Dictionary) -> SimResourceCatalog:
	var catalog := SimResourceCatalog.new()
	for key in raw:
		var id := String(key)
		if id.begins_with(COMMENT_PREFIX):
			continue
		catalog._food[id] = int(raw[key].get("food", 0))
		catalog._capacity[id] = int(raw[key].get("capacity", 0))
		catalog._order.append(id)
	return catalog


func ids() -> Array[String]:
	return _order.duplicate()


func has(resource_id: String) -> bool:
	return _food.has(resource_id)


## 한 단위가 몇 끼니 몫인가. 0이면 식량이 아니다.
func food_value(resource_id: String) -> int:
	return int(_food.get(resource_id, 0))


func is_food(resource_id: String) -> bool:
	return food_value(resource_id) > 0


func base_capacity(resource_id: String) -> int:
	return int(_capacity.get(resource_id, 0))


## 식량이 되는 자원들. 배급 순서를 정할 때 쓴다.
func food_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _order:
		if is_food(id):
			ids.append(id)
	return ids
