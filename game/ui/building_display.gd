class_name BuildingDisplay
extends RefCounted

## 건물의 표시 정보 — 한글 이름과 설명, 그리고 오류 문구.
##
## sim의 SimBuildingCatalog와 **같은 파일**(data/buildings.json)을 읽되,
## 서로 다른 키만 가져간다. sim은 숫자를, 여기는 문구를 읽는다.
## 이유는 ARCHITECTURE §2 규칙 2 — 시뮬레이션은 표현을 모른다.
##
## 두 계층이 같은 파일을 따로 파싱하므로 id가 어긋날 수 있다.
## 그 위험은 테스트가 막는다 (tests/run_tests.gd).

const COMMENT_PREFIX := "_"

## 커맨드 오류 코드 → 플레이어에게 보여줄 문구.
## sim은 코드만 반환한다 (SimCommand 참조).
const COMMAND_ERRORS := {
	SimBuildCommand.ERR_SLOT_OUT_OF_RANGE: "없는 슬롯입니다",
	SimBuildCommand.ERR_SLOT_LOCKED: "아직 해금되지 않은 자리입니다",
	SimBuildCommand.ERR_SLOT_OCCUPIED: "이미 건물이 있습니다",
	SimBuildCommand.ERR_UNKNOWN_TYPE: "알 수 없는 건물입니다",
	SimBuildCommand.ERR_TYPE_LOCKED: "선행 건물이 필요합니다",
	SimBuildCommand.ERR_CANNOT_AFFORD: "자원이 부족합니다",
	SimAssignWorkersCommand.ERR_NO_BUILDING: "건물이 없습니다",
	SimAssignWorkersCommand.ERR_NOT_COMPLETE: "아직 건설 중입니다",
	SimAssignWorkersCommand.ERR_NO_WORKER_SLOTS: "인력을 쓰지 않는 건물입니다",
	SimSetRecipeCommand.ERR_UNKNOWN_RECIPE: "만들 수 없는 것입니다",
	SimSetRationCommand.ERR_UNKNOWN_POLICY: "알 수 없는 배급 정책입니다",
}

## 생산이 멈춘 이유 → 문구. 홈 화면 배지와 건물 화면이 같은 표를 쓴다.
const HALT_MESSAGES := {
	SimBuilding.HALT_NO_WORKERS: "인력 없음",
	SimBuilding.HALT_NO_INPUT: "재료 없음",
	SimBuilding.HALT_STORAGE_FULL: "창고 가득",
}

## 홈 화면 슬롯 위에 띄우는 짧은 배지.
const HALT_BADGES := {
	SimBuilding.HALT_NO_WORKERS: "인력",
	SimBuilding.HALT_NO_INPUT: "재료",
	SimBuilding.HALT_STORAGE_FULL: "가득",
}

const POPULATION_EVENTS := {
	"family_arrived": "남부에서 한 가구가 이주해 왔다",
	"family_left": "견디다 못한 한 가구가 마을을 떠났다",
}

## 무엇이 모자랐는가 (SimVillage.last_shortage).
const SHORTAGE_MESSAGES := {
	"food": "먹을 것이 없다",
	"firewood": "땔 것이 없다",
	"both": "먹을 것도 땔 것도 없다",
}

const RATION_NAMES := {
	SimVillage.RATION_RICH_FIRST: "빵부터",
	SimVillage.RATION_CHEAP_FIRST: "잡곡부터",
}

const RATION_DESCRIPTIONS := {
	SimVillage.RATION_RICH_FIRST: "좋은 것부터 먹는다. 잡곡이 창고에 쌓인다",
	SimVillage.RATION_CHEAP_FIRST: "값싼 것부터 먹는다. 빵을 비축한다",
}

static var _names: Dictionary = {}
static var _descriptions: Dictionary = {}
static var _recipe_names: Dictionary = {}
static var _recipe_descriptions: Dictionary = {}
static var _loaded := false


static func name_of(type_id: String) -> String:
	_ensure_loaded()
	return _names.get(type_id, type_id)


static func description_of(type_id: String) -> String:
	_ensure_loaded()
	return _descriptions.get(type_id, "")


static func recipe_name(type_id: String, recipe_id: String) -> String:
	_ensure_loaded()
	return _recipe_names.get(_recipe_key(type_id, recipe_id), recipe_id)


static func recipe_description(type_id: String, recipe_id: String) -> String:
	_ensure_loaded()
	return _recipe_descriptions.get(_recipe_key(type_id, recipe_id), "")


static func command_error_message(code: String) -> String:
	return COMMAND_ERRORS.get(code, "할 수 없습니다")


static func halt_message(code: String) -> String:
	return HALT_MESSAGES.get(code, "")


static func halt_badge(code: String) -> String:
	return HALT_BADGES.get(code, "")


static func population_event_message(event: String) -> String:
	return POPULATION_EVENTS.get(event, "")


static func shortage_message(shortage: String) -> String:
	return SHORTAGE_MESSAGES.get(shortage, "")


static func ration_name(policy: String) -> String:
	return RATION_NAMES.get(policy, policy)


static func ration_description(policy: String) -> String:
	return RATION_DESCRIPTIONS.get(policy, "")


## 선행 건물 목록을 "농장 · 방앗간" 형태로.
static func requirement_list(type_ids: Array[String]) -> String:
	var names: Array[String] = []
	for type_id in type_ids:
		names.append(name_of(type_id))
	return " · ".join(names)


## "목재 20 · 석재 10"
static func format_cost(cost: Dictionary) -> String:
	return ResourceDisplay.format_flow(cost)


## "밀 3 → 밀가루 3" / 채취라면 "→ 목재 4"
static func format_recipe_flow(recipe: SimRecipe) -> String:
	var output := ResourceDisplay.format_flow(recipe.outputs)
	if recipe.is_gathering():
		return "→ %s" % output
	return "%s → %s" % [ResourceDisplay.format_flow(recipe.inputs), output]


static func _recipe_key(type_id: String, recipe_id: String) -> String:
	return "%s/%s" % [type_id, recipe_id]


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var raw := SimJson.read_dict(SimBuildingCatalog.DATA_PATH)
	for key in raw:
		var type_id := String(key)
		if type_id.begins_with(COMMENT_PREFIX):
			continue

		var entry: Dictionary = raw[key]
		_names[type_id] = String(entry.get("name", type_id))
		_descriptions[type_id] = String(entry.get("description", ""))

		for recipe in entry.get("recipes", []):
			var recipe_key := _recipe_key(type_id, String(recipe.get("id", "")))
			_recipe_names[recipe_key] = String(recipe.get("name", recipe.get("id", "")))
			_recipe_descriptions[recipe_key] = String(recipe.get("description", ""))
