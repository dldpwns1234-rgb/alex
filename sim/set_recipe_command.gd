class_name SimSetRecipeCommand
extends SimCommand

## 건물이 만들 것을 바꾼다.
##
## 농장의 작물 선택, 나무꾼 오두막의 목재/장작 선택이 전부 이 커맨드다
## (GDD §4.6). 건물마다 화면을 따로 만들지 않아도 되는 이유이기도 하다.

const ERR_NO_BUILDING := "no_building"
const ERR_NOT_COMPLETE := "not_complete"
const ERR_UNKNOWN_RECIPE := "unknown_recipe"

var slot_index: int
var recipe_id: String


func _init(target_slot: int, target_recipe_id: String) -> void:
	slot_index = target_slot
	recipe_id = target_recipe_id


func execute(world: SimWorld) -> String:
	var village := world.village
	var building := village.building_at(slot_index)

	if building == null:
		return ERR_NO_BUILDING
	if not building.is_complete():
		return ERR_NOT_COMPLETE
	if not village.type_of(building).has_recipe(recipe_id):
		return ERR_UNKNOWN_RECIPE

	# 진행 중이던 작업은 버려진다 (SimBuilding.set_recipe 참조).
	building.set_recipe(recipe_id)
	return OK
