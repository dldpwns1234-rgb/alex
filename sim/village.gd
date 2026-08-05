class_name SimVillage
extends RefCounted

## 마을 — 자원 · 슬롯 · 건물 (GDD §4.5).
##
## 슬롯 경제가 이 게임의 공간 퍼즐을 대체한다 (GDD §4.4).
## 슬롯은 유한하고, 무엇을 짓고 무엇을 포기할지가 곧 선택이다.

const LAYOUT_PATH := "res://data/village_layout.json"

## 슬롯 해금 조건. M1에서는 연차뿐이다.
## TODO(M2/M4): 인구 · 명성 조건 추가 (GDD §4.5).
var slot_unlock_years: Array[int] = []

var resources := SimResourcePool.new()
var catalog: SimBuildingCatalog

## 슬롯 번호 → SimBuilding. 비어 있는 슬롯은 키가 없다.
var buildings: Dictionary = {}

## 현재 연차 기준으로 해금된 슬롯 수. world가 틱마다 갱신한다.
var unlocked_slot_count: int = 0


static func load_default() -> SimVillage:
	return from_json(SimJson.read_dict(LAYOUT_PATH), SimBuildingCatalog.load_default())


static func from_json(layout: Dictionary, building_catalog: SimBuildingCatalog) -> SimVillage:
	var village := SimVillage.new()
	village.catalog = building_catalog
	village.resources = SimResourcePool.from_dict(layout.get("starting_resources", {}))

	for slot in layout.get("slots", []):
		village.slot_unlock_years.append(int(slot.get("unlock_year", 1)))

	village.refresh_slot_unlocks(1)
	return village


func slot_count() -> int:
	return slot_unlock_years.size()


func is_slot_unlocked(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < unlocked_slot_count


func building_at(slot_index: int) -> SimBuilding:
	return buildings.get(slot_index)


func is_slot_empty(slot_index: int) -> bool:
	return not buildings.has(slot_index)


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


## 하루치 건설 진행. 그날 완공된 건물들을 반환한다.
func advance_construction() -> Array[SimBuilding]:
	var completed: Array[SimBuilding] = []
	for slot_index in buildings:
		var building: SimBuilding = buildings[slot_index]
		if building.advance_construction():
			completed.append(building)
	return completed


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
