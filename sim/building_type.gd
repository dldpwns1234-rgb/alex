class_name SimBuildingType
extends RefCounted

## 건물 한 종류의 정의 — data/buildings.json 한 항목에 대응한다.
##
## 시뮬레이션이 알아야 하는 것만 담는다. 한글 이름과 설명은 여기 없다.
## 그것은 표현이고, game 계층의 BuildingDisplay가 같은 파일에서 읽는다
## (ARCHITECTURE §2 규칙 2).

var id: String = ""
## 자원 id → 필요 수량.
var cost: Dictionary = {}
var build_days: int = 0
## 배정할 수 있는 가구 수의 상한. 인력은 마을 전체에서 제로섬이다.
var workers: int = 0
## 수용하는 가구 수 (GDD §4.1 — 가구 하나 = 오두막 하나).
var housing: int = 0
## 모든 자원의 저장 한도에 더해지는 값.
var storage: int = 0
## 이 건물들이 완공되어 있어야 메뉴에서 해금된다 (GDD §4.5).
var requires: Array[String] = []
## 둘 이상이면 플레이어가 고른다. 비어 있으면 생산하지 않는 건물이다.
var recipes: Array[SimRecipe] = []


static func from_dict(type_id: String, raw: Dictionary) -> SimBuildingType:
	var type := SimBuildingType.new()
	type.id = type_id
	type.build_days = int(raw.get("build_days", 0))
	type.workers = int(raw.get("workers", 0))
	type.housing = int(raw.get("housing", 0))
	type.storage = int(raw.get("storage", 0))

	for resource_id in raw.get("cost", {}):
		type.cost[String(resource_id)] = int(raw["cost"][resource_id])

	for required_id in raw.get("requires", []):
		type.requires.append(String(required_id))

	for recipe_data in raw.get("recipes", []):
		type.recipes.append(SimRecipe.from_dict(recipe_data))

	return type


func produces() -> bool:
	return not recipes.is_empty()


func has_recipe(recipe_id: String) -> bool:
	return get_recipe(recipe_id) != null


func get_recipe(recipe_id: String) -> SimRecipe:
	for recipe in recipes:
		if recipe.id == recipe_id:
			return recipe
	return null


## 아무것도 고르지 않았을 때 쓰는 레시피. 데이터 파일의 첫 항목이다.
func default_recipe_id() -> String:
	return recipes[0].id if produces() else ""
