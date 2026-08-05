class_name BuildingDisplay
extends RefCounted

## 건물의 표시 정보 — 한글 이름과 설명.
##
## sim의 SimBuildingCatalog와 **같은 파일**(data/buildings.json)을 읽되,
## 서로 다른 키만 가져간다. sim은 숫자를, 여기는 문구를 읽는다.
## 이유는 ARCHITECTURE §2 규칙 2 — 시뮬레이션은 표현을 모른다.
##
## 두 계층이 같은 파일을 따로 파싱하므로 id가 어긋날 수 있다.
## 그 위험은 테스트가 막는다 (tests/run_tests.gd — "모든 건물에 한글 이름이 있다").

const COMMENT_PREFIX := "_"

## 커맨드 오류 코드 → 플레이어에게 보여줄 문구.
## sim은 코드만 반환한다 (SimCommand 참조).
const BUILD_ERRORS := {
	SimBuildCommand.ERR_SLOT_OUT_OF_RANGE: "없는 슬롯입니다",
	SimBuildCommand.ERR_SLOT_LOCKED: "아직 해금되지 않은 자리입니다",
	SimBuildCommand.ERR_SLOT_OCCUPIED: "이미 건물이 있습니다",
	SimBuildCommand.ERR_UNKNOWN_TYPE: "알 수 없는 건물입니다",
	SimBuildCommand.ERR_TYPE_LOCKED: "선행 건물이 필요합니다",
	SimBuildCommand.ERR_CANNOT_AFFORD: "자원이 부족합니다",
}

static var _names: Dictionary = {}
static var _descriptions: Dictionary = {}
static var _loaded := false


static func name_of(type_id: String) -> String:
	_ensure_loaded()
	return _names.get(type_id, type_id)


static func description_of(type_id: String) -> String:
	_ensure_loaded()
	return _descriptions.get(type_id, "")


static func build_error_message(code: String) -> String:
	return BUILD_ERRORS.get(code, "건설할 수 없습니다")


## 선행 건물 목록을 "농장 · 방앗간" 형태로.
static func requirement_list(type_ids: Array[String]) -> String:
	var names: Array[String] = []
	for type_id in type_ids:
		names.append(name_of(type_id))
	return " · ".join(names)


## "목재 20 · 석재 10"
static func format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in ResourceDisplay.ordered(cost.keys()):
		parts.append("%s %d" % [ResourceDisplay.name_of(resource_id), int(cost[resource_id])])
	return " · ".join(parts)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var raw := SimJson.read_dict(SimBuildingCatalog.DATA_PATH)
	for key in raw:
		var type_id := String(key)
		if type_id.begins_with(COMMENT_PREFIX):
			continue
		_names[type_id] = String(raw[key].get("name", type_id))
		_descriptions[type_id] = String(raw[key].get("description", ""))
