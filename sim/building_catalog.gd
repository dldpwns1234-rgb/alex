class_name SimBuildingCatalog
extends RefCounted

## data/buildings.json을 읽어 건물 정의 목록으로 만든다 (ARCHITECTURE §5).
##
## 순서를 보존한다. 메뉴에 뜨는 순서가 곧 데이터 파일에 적힌 순서이므로,
## 해금 사슬 순으로 적어두면 메뉴도 그 순서로 나온다.

const DATA_PATH := "res://data/buildings.json"

## `_`로 시작하는 키는 주석이다. 정의가 아니다.
const COMMENT_PREFIX := "_"

var _types: Dictionary = {}
var _order: Array[String] = []


static func load_default() -> SimBuildingCatalog:
	return from_json(SimJson.read_dict(DATA_PATH))


static func from_json(raw: Dictionary) -> SimBuildingCatalog:
	var catalog := SimBuildingCatalog.new()
	for key in raw:
		var type_id := String(key)
		if type_id.begins_with(COMMENT_PREFIX):
			continue
		catalog._types[type_id] = SimBuildingType.from_dict(type_id, raw[key])
		catalog._order.append(type_id)
	return catalog


func has(type_id: String) -> bool:
	return _types.has(type_id)


func get_type(type_id: String) -> SimBuildingType:
	return _types.get(type_id)


## 데이터 파일에 적힌 순서 그대로.
func ids() -> Array[String]:
	return _order.duplicate()


## 선행 건물이 전부 완공되었는가 (GDD §4.5 해금 사슬).
##
## `completed_ids`는 건설이 끝난 건물들의 종류 id 집합이다.
## 건설 중인 건물은 포함되지 않는다 — 짓는 중에 다음 단계가 열리면
## 사슬이 의미를 잃는다.
func is_unlocked(type_id: String, completed_ids: Dictionary) -> bool:
	var type := get_type(type_id)
	if type == null:
		return false
	for required_id in type.requires:
		if not completed_ids.has(required_id):
			return false
	return true


## 아직 만족하지 못한 선행 건물들. 메뉴에서 "무엇이 필요한가"를 보여주는 데 쓴다.
func missing_requirements(type_id: String, completed_ids: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	var type := get_type(type_id)
	if type == null:
		return missing
	for required_id in type.requires:
		if not completed_ids.has(required_id):
			missing.append(required_id)
	return missing
